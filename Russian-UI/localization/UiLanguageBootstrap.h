#pragma once
// GUI-only bootstrap. No MainCore, DSP, radio, REST or serialization dependencies.
#include <QApplication>
#include <QTranslator>
#include <QSettings>
#include <QDir>
#include <QMainWindow>
#include <QMenuBar>
#include <QActionGroup>
#include <QAction>
#include <QMessageBox>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QFile>
#include <QLabel>
#include <QAbstractButton>
#include <QFontMetrics>
#include <QTextDocument>
#include <QDateTime>
#include <QDebug>

namespace UiLanguageBootstrap {
inline void initializeSettingsStorage() {
    // Optional test profile; original organization, application and setting keys stay intact.
    const QString folder=qEnvironmentVariable("SDRANGEL_UI_PROFILE_DIR");
    if(!folder.isEmpty()) {
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,folder);
        QSettings::setPath(QSettings::IniFormat,QSettings::SystemScope,folder);
    }
}
inline QString requestedLanguage() {
    const QString overrideCode=qEnvironmentVariable("SDRANGEL_UI_LANGUAGE");
    const QString stored=QSettings().value("interface.language", "ru").toString();
    return (overrideCode.isEmpty()?stored:overrideCode)=="ru"?"ru":"en";
}
inline void initialize(QApplication& app) {
    QString active="en";
    if(requestedLanguage()=="ru") {
        const QString folder=QDir(app.applicationDirPath()).filePath("translations");
        auto* translatedApp=new QTranslator(&app);
        if(translatedApp->load("sdrangel_ru", folder)) {
            auto* translatedQt=new QTranslator(&app);
            if(translatedQt->load("qt_ru", folder)) app.installTranslator(translatedQt);
            app.installTranslator(translatedApp);
            active="ru";
        } else {
            qWarning("Russian application catalog missing; GUI remains English");
        }
    }
    app.setProperty("uiLanguageActive",active);
    // Do not change QLocale default: numeric/API/driver formatting stays unchanged.
}
inline void auditVisibleUi(QMainWindow& window) {
    QJsonArray rows;
    for(auto* top:QApplication::topLevelWidgets()) {
        auto widgets=top->findChildren<QWidget*>();widgets.prepend(top);
        for(auto* widget:widgets) {
            if(!widget->isVisible()) continue;
            QString text;
            bool wrapped=false;
            if(auto* label=qobject_cast<QLabel*>(widget)){text=label->text();wrapped=label->wordWrap();}
            else if(auto* button=qobject_cast<QAbstractButton*>(widget)){text=button->text();}
            if(text.isEmpty()) continue;
            const QFontMetrics metrics(widget->font());
            QJsonObject row;
            row["class"]=widget->metaObject()->className();row["objectName"]=widget->objectName();
            row["text"]=text;row["font"]=widget->font().family();
            QString missingGlyphs;
            for(const auto character:text) {
                const auto code=character.unicode();
                if(code>=0x0400 && code<=0x052f && !metrics.inFontUcs4(code)
                    && !missingGlyphs.contains(character)) missingGlyphs.append(character);
            }
            row["cyrillicGlyphsAvailable"]=missingGlyphs.isEmpty();
            row["missingCyrillicGlyphs"]=missingGlyphs;
            QRect available=widget->contentsRect();
            bool measured=true;
            int flags=wrapped?Qt::TextWordWrap:Qt::TextSingleLine;
            if(auto* label=qobject_cast<QLabel*>(widget)) {
                available.adjust(label->margin(),label->margin(),-label->margin(),-label->margin());
                int indent=label->indent();
                if(indent<0) indent=label->frameWidth()>0?metrics.horizontalAdvance('x')/2:0;
                if(label->alignment() & Qt::AlignLeft) available.adjust(indent,0,0,0);
                if(label->alignment() & Qt::AlignRight) available.adjust(0,0,-indent,0);
                measured=label->textFormat()==Qt::PlainText ||
                    (label->textFormat()==Qt::AutoText && !Qt::mightBeRichText(text));
            } else if(qobject_cast<QAbstractButton*>(widget)) {
                // Button subclasses, icons and platform styles need visual verification.
                measured=false;
                flags|=Qt::TextShowMnemonic;
            }
            const QRect needed=metrics.boundingRect(available,flags,text);
            row["availableWidth"]=available.width();row["availableHeight"]=available.height();
            row["neededWidth"]=needed.width();row["neededHeight"]=needed.height();
            row["measurementAvailable"]=measured;
            if(measured) row["potentialClipping"]=needed.width()>available.width()||needed.height()>available.height();
            else row["manualReviewRequired"]=true;
            rows.append(row);
        }
    }
    QJsonObject report;report["language"]=qApp->property("uiLanguageActive").toString();
    report["scope"]="visible widgets only; manual visual verification still required";report["widgets"]=rows;
    report["timestampUtc"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    report["devicePixelRatio"]=window.devicePixelRatioF();
    report["completeVisualVerification"]=false;
    QFile file(QDir::current().filePath("ui-localization-audit.json"));
    if(file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(report).toJson());
        QMessageBox::information(&window,QString::fromUtf8("Проверка интерфейса / UI check"),
            QString::fromUtf8("Отчёт записан в ui-localization-audit.json. Проверьте также меню, подсказки и окна визуально."));
    } else QMessageBox::warning(&window,"UI check","Cannot write ui-localization-audit.json");
}
inline void attachMenu(QMainWindow& window) {
    auto* menu=window.menuBar()->addMenu(QString::fromUtf8("Язык / Language"));
    menu->setObjectName("interfaceLanguageMenu");
    auto* group=new QActionGroup(menu);group->setExclusive(true);
    const QString active=qApp->property("uiLanguageActive").toString();
    const auto add=[&](const QString& label,const QString& code) {
        auto* action=menu->addAction(label);action->setCheckable(true);group->addAction(action);
        action->setChecked(active==code);
        QObject::connect(action,&QAction::triggered,&window,[&window,code] {
            QSettings().setValue("interface.language",code);
            QMessageBox::information(&window,QString::fromUtf8("Язык / Language"),
                QString::fromUtf8("Язык изменится после обычного перезапуска SDRangel.\nLanguage changes after a normal SDRangel restart."));
        });
    };
    add(QString::fromUtf8("Русский"),"ru");add("English","en");
    menu->addSeparator();
    auto* audit=menu->addAction(QString::fromUtf8("Проверить надписи / Check labels"));
    QObject::connect(audit,&QAction::triggered,&window,[&window]{auditVisibleUi(window);});
}
}
