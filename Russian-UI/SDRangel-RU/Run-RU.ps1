[CmdletBinding()]
param([ValidateSet('ru','en')][string]$Language)
$ErrorActionPreference='Stop'
$guiStarted=$false
trap {
 $failure=[ordered]@{success=$false;guiStarted=$guiStarted;error=$_.Exception.Message;timestampUtc=[DateTime]::UtcNow.ToString('o')}
 $failure|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'logs\run-last.json') -Encoding UTF8
 Write-Host ('FAILED: '+$_.Exception.Message) -ForegroundColor Red
 exit 1
}
$root=$PSScriptRoot;$manifest=Join-Path $root 'logs\build-artifact.json'
if(-not (Test-Path -LiteralPath $manifest)){throw 'No verified build artifact. Run buildru.cmd first.'}
$artifact=Get-Content $manifest -Raw -Encoding UTF8|ConvertFrom-Json
if(-not $artifact.built -or -not $artifact.isolatedSettingsBootstrapped){throw 'Build is not ready for isolated GUI testing'}
. (Join-Path $root 'Build-Core.ps1')
$exe=Assert-RuPath $artifact.executable $root
if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne $artifact.executableSha256){throw 'Executable changed after build verification'}
$existing=@(Get-Process -Name sdrangel -ErrorAction SilentlyContinue)
if($existing.Count){throw ('Close SDRangel normally before testing the separate build. Existing PIDs: '+(($existing|ForEach-Object Id) -join ', '))}
$port=8092;$listener=New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Loopback),$port
try{$listener.Start()}finally{$listener.Stop()}
$profile=Join-Path $root 'profile';New-Item -ItemType Directory -Force $profile|Out-Null
$backup=Join-Path (Split-Path $root -Parent) ('SDRangelBackups\ru-before-launch-'+(Get-Date -Format yyyyMMdd-HHmmss-fff));New-Item -ItemType Directory -Force $backup|Out-Null
Copy-Item -LiteralPath $profile -Destination $backup -Recurse
# Read-only registry export protects the installed GUI's settings as an additional precaution.
if(Test-Path 'HKCU:\Software\f4exb\SDRangel'){
 & reg.exe export 'HKCU\Software\f4exb\SDRangel' (Join-Path $backup 'installed-SDRangel.reg') /y|Out-Host
 if($LASTEXITCODE -ne 0){throw 'Could not back up installed settings; test GUI was not launched'}
}
$env:SDRANGEL_UI_PROFILE_DIR=$profile
if($Language){$env:SDRANGEL_UI_LANGUAGE=$Language}else{Remove-Item Env:SDRANGEL_UI_LANGUAGE -ErrorAction SilentlyContinue}
$run=Join-Path $root ('logs\gui-'+(Get-Date -Format yyyyMMdd-HHmmss-fff));New-Item -ItemType Directory -Force $run|Out-Null
# No --start and no remote-TCP mode. A clean, idle UI test on a separate REST port.
$process=Start-Process -FilePath $exe -ArgumentList @('--scratch','-a','127.0.0.1','-p',[string]$port) -WorkingDirectory $run -PassThru -RedirectStandardOutput (Join-Path $run 'stdout.log') -RedirectStandardError (Join-Path $run 'stderr.log')
$guiStarted=$true
[ordered]@{pid=$process.Id;executable=$exe;api='http://127.0.0.1:8092/sdrangel';profile=$profile;backup=$backup;languageOverride=$Language;rxStarted=$false;txStarted=$false;guiRenderingConfirmed=$false}|ConvertTo-Json|Set-Content (Join-Path $run 'launch.json') -Encoding UTF8
Write-Host "Separate idle test GUI started, PID $($process.Id). This is not evidence of rendering or hardware compatibility."
