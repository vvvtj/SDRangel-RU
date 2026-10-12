# Проверка русификации SDRangel 7.27.2

Проверены официальные исходники тега v7.27.2: app/main.cpp, sdrgui/mainwindow.cpp и корневой CMakeLists.txt. В проверенных точках запуска нет QTranslator/installTranslator; CMake не содержит подключения translation/Linguist. В mainwindow.cpp есть tr(), то есть часть надписей уже пригодна для Qt-перевода. Готовый русский каталог самого SDRangel в установленной копии не найден. Полный рекурсивный аудит исходников пока невозможен: checkout в проекте отсутствует.

В C:/Program Files/SDRangel/translations найден qt_ru.qm (229649 байт). Это каталог Qt; наличие этого файла не означает перевод SDRangel, его меню, спектра или PlutoSDR MIMO. Простое копирование ещё одного QM не включит язык без загрузки QTranslator в приложении.

В проекте и стандартных проверенных каталогах не найдены Qt SDK/lrelease/lupdate, CMake, Git или Visual Studio. Исходники полной сборки также отсутствуют. Поэтому установленный GUI сейчас не переведён и не пересобран; отображение кириллицы и отсутствие обрезания в работающем SDRangel не подтверждены.

Подготовлена основа для сборки: UiLanguageBootstrap.h, GUI-only патчер Apply-RussianUi.ps1 и начальный sdrangel_ru.ts. Патчер меняет только app/main.cpp и добавляет GUI-заголовок/каталог; предварительно копирует оригиналы в SDRangelBackups. Он не меняет REST API, протоколы, драйверы, libiio, DSP/IQ и существующие технические ключи. Новая отдельная GUI-настройка interface.language не переименовывает старые ключи. Глобальная QLocale не меняется, чтобы формат чисел в технических интерфейсах оставался прежним.

Переключатель Русский / English применяется после обычного перезапуска. Он не останавливает и не запускает радио. QTranslator живёт вместе с QApplication и устанавливается до создания MainWindow. При отсутствии sdrangel_ru.qm интерфейс остаётся English с предупреждением; русский язык не объявляется загруженным.

Каталог TS является начальным, а не полным переводом всех окон. После получения полного checkout необходимо выполнить lupdate для GUI/.ui и дополнить реальные строки/контексты, включая PlutoSDRMIMOGUI. Непереведённые и не обёрнутые в tr() строки останутся английскими. Нельзя переименовывать objectName, deviceHwType, direction, URI, JSON/API-ключи или сериализованные поля ради перевода надписей.

В меню добавлен диагностический пункт Check labels: в собранном GUI он создаёт ui-localization-audit.json для видимых QLabel/кнопок, проверяет наличие кириллических глифов выбранного шрифта и потенциальное обрезание по QFontMetrics. Это предварительная проверка; rich text, иконки, меню и подсказки требуют визуального осмотра. Закрытые окна так не проверяются. Проверить отдельно MainWindow, настройки/конфигурации, RX-only, MIMO RX0/RX1, спектр, водопад, подсказки при масштабе Windows 100/125/150%. Проверка на экране здесь пока не выполнена.

Источники: [app/main.cpp 7.27.2](https://raw.githubusercontent.com/f4exb/sdrangel/v7.27.2/app/main.cpp), [mainwindow.cpp 7.27.2](https://raw.githubusercontent.com/f4exb/sdrangel/v7.27.2/sdrgui/mainwindow.cpp), [CMake 7.27.2](https://raw.githubusercontent.com/f4exb/sdrangel/v7.27.2/CMakeLists.txt), [Qt QTranslator](https://doc.qt.io/qt-6/qtranslator.html).
