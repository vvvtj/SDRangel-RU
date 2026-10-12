# SDRangel 7.27.2 Russian UI project

Materials for a separate Windows build are in this directory. The catalog is a preliminary seed of 576 messages, not full coverage. No working Russian executable has been compiled or visually tested yet.

Start with SDRangel-RU/README.md. buildru.cmd obtains the complete v7.27.2 checkout, extracts real GUI contexts with lupdate, prepares the translation catalog and builds a separate application when Qt 6.9.3/MSVC/CMake dependencies are installed. runru.cmd is for that future test build.

This commit contains GUI localization/build materials only. Radio drivers, REST API, libiio and IQ code are not edited by the localization patch. No firmware, device settings, backups or authentication files are included.