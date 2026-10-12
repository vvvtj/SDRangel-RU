@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0SDRangel-RU\Run-RU.ps1" %*
set "RU_EXIT=%ERRORLEVEL%"
if "%RU_EXIT%"=="0" exit /b 0
pause
exit /b %RU_EXIT%
