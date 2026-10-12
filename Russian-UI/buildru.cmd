@echo off
setlocal
cd /d "%~dp0"
set "PATH=%PATH%;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;C:\Program Files\CMake\bin;C:\Program Files (x86)\NSIS;C:\Qt\Tools\Ninja"
set "VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto run
for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -version "[17.0,18.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "RU_VS=%%I"
if not defined RU_VS goto run
call "%RU_VS%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
if errorlevel 1 goto vsfailed
:run
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0SDRangel-RU\Build-RU.ps1" %*
set "RU_EXIT=%ERRORLEVEL%"
echo Logs: %~dp0SDRangel-RU\logs
pause
exit /b %RU_EXIT%
:vsfailed
echo MSVC environment initialization failed.
pause
exit /b 1
