# Отдельная тестовая сборка SDRangel-RU 7.27.2

Исполняемый файл пока **не собран**. Здесь находится сценарий сборки и диагностика отсутствующих инструментов. Исходники и инструменты ещё необходимо получить в обычной Windows. Установленная SDRangel не заменяется.

## Что установить

| Компонент | Точный выбор для этого сценария |
|---|---|
| Visual Studio 2022 Community или Build Tools 2022 | «Desktop development with C++» / «Разработка классических приложений на C++», MSVC v143 x64/x86, Windows 10/11 SDK, C++ MFC для v143 x86/x64. |
| Qt SDK | Qt **6.9.3**, **MSVC 2022 64-bit**, каталог `C:\Qt\6.9.3\msvc2022_64`. Не MinGW. |
| Дополнительные модули Qt | Charts, StateMachine (пакет qtscxml), Qt5Compat, Location, Multimedia, Positioning, SerialPort, ShaderTools, Speech/TextToSpeech, WebSockets, WebChannel, WebEngine. Базовые Widgets, Quick, OpenGL, SVG входят в проверку SDK. |
| Инструменты Qt | Linguist Tools: `lupdate.exe`, `lrelease.exe`; также `qmake.exe`, `windeployqt.exe`. Нужны SDK/заголовки, включая приватные заголовки QtCore, а не только DLL установленного приложения. |
| Git for Windows | Git в PATH; GNU `patch.exe`, обычно в `Git\usr\bin`. Если patch отсутствует, установить отдельно, как в официальном CI. |
| CMake, Ninja, NSIS | Исполняемые файлы в PATH либо полный путь в `build-config.json`. NSIS нужен для цели `package`; полученный установщик сценарий не запускает. |
| Boost | Архив исходников **1.73.0**, распаковать так, чтобы существовал `C:\Libraries\boost_1_73_0\boost\version.hpp`. |
| Библиотеки Windows SDRangel | Получаются автоматически через `git submodule update --init --recursive` по commit подмодуля, закреплённому в теге. Сетевой доступ нужен также для ExternalProject-зависимостей сборки. |

Выбор Qt 6.9.3/MSVC 2022 и Boost 1.73.0 основан на [официальном Windows workflow тега v7.27.2](https://github.com/f4exb/sdrangel/blob/v7.27.2/.github/workflows/windows.yml). В workflow есть несогласованность: Qt устанавливается как `msvc2022_64`, но строка configure указывает `msvc2019_64`. Здесь используется фактически установленный SDK `msvc2022_64`.

Требования Visual Studio/MFC и порядок сборки: [официальная инструкция Windows](https://github.com/f4exb/sdrangel/wiki/Compile-in-Windows). Подмодуль: [`.gitmodules` v7.27.2](https://github.com/f4exb/sdrangel/blob/v7.27.2/.gitmodules). CUDA для этого сценария не устанавливается.

Загрузки: [Visual Studio](https://visualstudio.microsoft.com/vs/community/), [Qt Open Source](https://www.qt.io/download-open-source), [Git](https://git-scm.com/download/win), [CMake](https://cmake.org/download/), [Ninja](https://github.com/ninja-build/ninja/releases), [NSIS](https://nsis.sourceforge.io/Download), [Boost 1.73.0](https://archives.boost.io/release/1.73.0/source/boost_1_73_0.tar.bz2).

## Запуск сборки

После установки поправить пути в `build-config.json`, если они отличаются. Из папки проекта:

```cmd
buildru.cmd -Stage Inventory
buildru.cmd -Stage Checkout
buildru.cmd -Stage Extract
buildru.cmd -Stage Build
```

Или двойной щелчок по `buildru.cmd` выполняет все стадии. CMD подключает окружение VS 2022 x64 через vswhere, запускает отдельный PowerShell с ExecutionPolicy Bypass и сохраняет логи. Системная политика PowerShell не меняется. При ошибке ничего не выдаётся за успешную сборку; резервные копии сохраняются.

Checkout содержит все файлы тега, а не выборку исходников. Проверяются HEAD, commit тега и состояние всех подмодулей; `source-lock.json` записывает точные commit. Скрипт не выполняет git reset/clean и не удаляет существующий checkout.

Структура результата: `source` — исходники, `build` — сборка/установщик, `app` — отдельная тестовая программа, `catalog` — переводы и покрытие, `profile` — отдельные настройки, `logs` — команды, ошибки и отчёты.

## Реальный каталог и проверка перевода

`lupdate` читает `.ui` и исходники GUI из app/sdrgui, а также GUI/dialog/widget-файлы плагинов. Команды/список файлов сохраняются. Это извлечение известных Qt-переводимых строк, а не доказательство охвата всех жёстко заданных надписей. [Интерфейс lupdate](https://doc.qt.io/qt-6/linguist-lupdate.html).

`Merge-Catalog.ps1` сопоставляет **контекст + исходный текст + comment + numerus**, с учётом регистра. Предложения из другого контекста остаются `unfinished`. Строки без совпадений и множественные формы требуют перевода. Подстановки проверяются; русский numerus требует три формы. `.qm` собирается с `-nounfinished`.

В `catalog/coverage.json` и CSV будут фактические количества; до успешного lupdate этого отчёта о реальных исходниках нет. Фикстуры локальных тестов находятся отдельно в logs и не являются извлечением SDRangel. Предварительные 576 записей не считаются покрытием.

Для дополнения открыть `catalog/sdrangel_ru.ts` в Qt Linguist, проверить предложения, перевести отсутствующие строки, сохранить **отдельно** как `catalog/reviewed-ru.ts`. Повторный Extract/Build использует этот проверенный каталог. `gui-literal-review.csv` в каталоге запуска содержит оставшиеся литералы пяти основных GUI-файлов. Автоматическая обёртка затрагивает только известные подписи в конкретных presentation-setter вызовах; остальные требуют осмотра исходников.

Изменения исходников ограничены app/main.cpp, GUI-заголовком, сборкой каталога и перечисленными GUI-файлами. REST/Swagger, сериализация, драйверы, DSP/IQ, libiio и технические ключи не редактируются. `ENABLE_IIO=ON` обязателен. Исходники API не исправляются даже при известных ограничениях MIMO REST в этой версии.

## Проверка тестовой программы

После успешной сборки закрыть рабочую SDRangel обычным способом и запустить `runru.cmd`. Он проверяет hash артефакта, делает резервную копию тестового профиля/доступных текущих настроек, использует отдельное INI-хранилище, REST на 127.0.0.1:8092 и `--scratch`. RX/TX автоматически не запускаются. Профили сохраняются отдельно; установленная программа продолжает использовать своё прежнее хранилище.

Меню «Язык / Language» выбирает Русский / English после перезапуска. Для одноразовой проверки можно вызвать `runru.cmd -Language en` или `-Language ru`; при обычном запуске сохраняется выбор меню. [Порядок визуальной проверки](../localization/VISUAL-CHECK.md) включает главное меню, настройки, конфигурации, PlutoSDR MIMO, спектр/водопад и масштабы Windows 100/125/150%. Диагностический JSON создаётся в `logs/gui-*`.

Работающее окно само по себе не доказывает совместимость с ANTSDR: отдельно нужны импорт копии RX-only/MIMO-профиля, read-back настроек через API и реальные IQ/FFT для RX. Все команды запуска TX запрещены. Аппаратные проверки и визуальные проверки пока не выполнены. Не переносить эту сборку поверх рабочей до их завершения.
