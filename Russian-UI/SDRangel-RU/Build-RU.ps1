[CmdletBinding()]
param([ValidateSet('Inventory','Checkout','Extract','Build','All')][string]$Stage='All',[string]$ConfigFile)
$ErrorActionPreference='Stop'
if(-not $ConfigFile){$ConfigFile=Join-Path $PSScriptRoot 'build-config.json'}
. (Join-Path $PSScriptRoot 'Build-Core.ps1')
$root=$PSScriptRoot;$project=Split-Path $root -Parent;$config=Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8|ConvertFrom-Json
if($config.tag -ne 'v7.27.2' -or $config.expectedCommitPrefix -ne '97e9e21'){throw 'This workflow is pinned to SDRangel v7.27.2 / 97e9e21'}
if([int]$config.parallel -lt 1 -or [int]$config.parallel -gt 64){throw 'Invalid parallel build count'}
$run=Join-Path $root ('logs\'+(Get-Date -Format yyyyMMdd-HHmmss-fff));New-Item -ItemType Directory -Force $run|Out-Null
$source=Assert-RuPath (Join-Path $root 'source') $root
$build=Assert-RuPath (Join-Path $root 'build') $root
$app=Assert-RuPath (Join-Path $root 'app') $root
$catalog=Join-Path $root 'catalog';New-Item -ItemType Directory -Force $catalog|Out-Null
$status=[ordered]@{stage=$Stage;success=$false;sourceCheckoutVerified=$false;realStringsExtracted=$false;compiled=$false;portableAppPrepared=$false;fullTranslationComplete=$false;guiTested=$false;hardwareTested=$false;logDirectory=$run}
Start-Transcript -Path (Join-Path $run 'transcript.txt')|Out-Null
try {
 $inventory=Get-RuInventory $config $root
 $inventory|ConvertTo-Json -Depth 8|Set-Content (Join-Path $root 'logs\inventory.json') -Encoding UTF8
 $inventory|ConvertTo-Json -Depth 8|Set-Content (Join-Path $run 'inventory.json') -Encoding UTF8
 if($Stage -eq 'Inventory'){$status.success=$true;Write-Host ('Missing tools/modules: '+($inventory.missingToolsAndModules -join ', '));return}
 $git=$inventory.tools.git
 if(-not $git){throw 'Git is missing. Install Git for Windows, then rerun buildru.cmd.'}
 $nativeLog=Join-Path $run 'native.log'
 if($Stage -in @('Checkout','All')) {
  if(-not (Test-Path -LiteralPath $source)){
   Invoke-RuNative $git @('clone','--branch','v7.27.2','--single-branch','https://github.com/f4exb/sdrangel.git',$source) $nativeLog
  } elseif(-not (Test-Path -LiteralPath (Join-Path $source '.git'))){throw 'Existing source directory is not a Git checkout; it will not be deleted or overwritten'}
 }
 if(-not (Test-Path -LiteralPath (Join-Path $source '.git'))){throw 'Full checkout missing; run stage Checkout first'}
 $head=(& $git -C $source rev-parse HEAD);if($LASTEXITCODE -ne 0){throw 'Cannot read HEAD'}
 $tagCommit=(& $git -C $source rev-parse 'v7.27.2^{commit}');if($LASTEXITCODE -ne 0){throw 'Tag v7.27.2 missing'}
 if($head -ne $tagCommit -or -not $head.StartsWith($config.expectedCommitPrefix)){throw 'Checkout is not the pinned v7.27.2 commit'}
 if($Stage -in @('Checkout','All')){Invoke-RuNative $git @('-C',$source,'submodule','update','--init','--recursive') $nativeLog}
 $submodules=@(& $git -C $source submodule status --recursive);if($LASTEXITCODE -ne 0){throw 'Submodule status failed'}
 if(-not $submodules.Count -or @($submodules|Where-Object {$_ -match '^[-+U]'}).Count){throw 'Submodule missing, conflicted or not at the tag-pinned commit'}
 [ordered]@{tag='v7.27.2';commit=$head;submodules=$submodules}|ConvertTo-Json|Set-Content (Join-Path $root 'logs\source-lock.json') -Encoding UTF8
 $status.sourceCheckoutVerified=$true
 if($Stage -eq 'Checkout'){$status.success=$true;return}
 foreach($name in @('lupdate','lrelease')){if(-not $inventory.tools[$name]){throw "Qt SDK tool missing: $name"}}
 $backup=Join-Path $project ('SDRangelBackups\ru-source-'+(Get-Date -Format yyyyMMdd-HHmmss-fff));New-Item -ItemType Directory -Force $backup|Out-Null
 $main=Join-Path $source 'app\main.cpp'
 if(-not ([IO.File]::ReadAllText($main).Contains('UiLanguageBootstrap'))){& (Join-Path $project 'localization\Apply-RussianUi.ps1') -SourceRoot $source}
 # An older patch without isolated settings must not be silently reused.
 if(-not ([IO.File]::ReadAllText($main).Contains('UiLanguageBootstrap::initializeSettingsStorage();'))){throw 'Existing GUI patch predates isolated settings; restore its backed-up main.cpp and reapply'}
 $header=Join-Path $source 'app\UiLanguageBootstrap.h';Copy-Item -LiteralPath $header -Destination (Join-Path $backup 'UiLanguageBootstrap.h')
 [IO.File]::WriteAllText($header,[IO.File]::ReadAllText((Join-Path $project 'localization\UiLanguageBootstrap.h'),[Text.Encoding]::UTF8),(New-Object Text.UTF8Encoding $true))
 & (Join-Path $root 'Prepare-UiStrings.ps1') -SourceRoot $source -BackupDirectory $backup -ReportDirectory $run
 $extracted=Join-Path $catalog 'extracted-en.ts'
 if(Test-Path -LiteralPath $extracted){Copy-Item -LiteralPath $extracted -Destination (Join-Path $backup 'extracted-en.ts')}
 # Extract every GUI/plugin UI context, while excluding backend/API/driver trees.
 $roots=@((Join-Path $source 'app'),(Join-Path $source 'sdrgui'),(Join-Path $source 'plugins'))
 $files=@(foreach($directory in $roots){Get-ChildItem -LiteralPath $directory -Recurse -File|Where-Object { $_.Extension -in @('.ui','.qml') -or ($_.Name -match '(gui|dialog|widget)\.(cpp|h)$') -or ($directory -ne (Join-Path $source 'plugins') -and $_.Extension -in @('.cpp','.h')) }|ForEach-Object FullName})
 if($files.Count -lt 100){throw 'Unexpectedly incomplete GUI source list'}
 $list=Join-Path $run 'lupdate-files.txt';[IO.File]::WriteAllLines($list,[string[]]@($files|ForEach-Object {$_.Replace('\','/')}),(New-Object Text.UTF8Encoding $false))
 Invoke-RuNative $inventory.tools.lupdate @(('@'+$list),'-no-obsolete','-locations','relative','-ts',$extracted) $nativeLog
 $merged=Join-Path $source 'translations\sdrangel_ru.ts'
 if(Test-Path -LiteralPath $merged){Copy-Item -LiteralPath $merged -Destination (Join-Path $backup 'sdrangel_ru.ts')}
 $seed=Join-Path $catalog 'reviewed-ru.ts';if(-not (Test-Path -LiteralPath $seed)){$seed=Join-Path $project 'localization\sdrangel_ru.ts'}
 & (Join-Path $root 'Merge-Catalog.ps1') -Extracted $extracted -Seed $seed -Output $merged -ReportDirectory $catalog
 Copy-Item -LiteralPath $merged -Destination (Join-Path $catalog 'sdrangel_ru.ts')
 $coverage=Get-Content (Join-Path $catalog 'coverage.json') -Raw -Encoding UTF8|ConvertFrom-Json
 $status.realStringsExtracted=$true;$status.fullTranslationComplete=$coverage.complete
 Invoke-RuNative $inventory.tools.lrelease @($merged,'-nounfinished','-qm',(Join-Path $catalog 'sdrangel_ru.qm')) $nativeLog
 Add-RuCMakeIntegration $source $backup
 $allowed=@('app/main.cpp','CMakeLists.txt','sdrgui/mainwindow.cpp','sdrgui/gui/glspectrumgui.cpp','sdrgui/gui/spectrumgui.cpp','plugins/samplesource/plutosdrinput/plutosdrinputgui.cpp','plugins/samplemimo/plutosdrmimo/plutosdrmimogui.cpp')
 $changed=@(& $git -C $source diff --name-only);if($LASTEXITCODE -ne 0){throw 'Cannot audit source diff'}
 foreach($path in $changed){if($path -notin $allowed){throw "Unexpected source modification (backend/config compatibility not established): $path"}}
 & $git -C $source diff --binary|Set-Content (Join-Path $run 'gui-only.patch') -Encoding UTF8
 $settingsFiles=@(Get-ChildItem -LiteralPath $source -Recurse -File -Include *.cpp,*.h|Where-Object {$_.FullName -notlike '*\external\windows\*'})
 $nativeSettings=@($settingsFiles|Select-String -Pattern 'QSettings::NativeFormat')
 [ordered]@{isolatedDefaultsPatched=$true;explicitNativeFormatOccurrences=@($nativeSettings|ForEach-Object { $_.Path+':'+$_.LineNumber });reviewRequired=($nativeSettings.Count -gt 0)}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $catalog 'settings-storage-review.json') -Encoding UTF8
 if($Stage -eq 'Extract'){$status.success=$true;return}
 if($inventory.missingToolsAndModules.Count){throw ('Cannot build; missing: '+($inventory.missingToolsAndModules -join ', '))}
 if($nativeSettings.Count){throw 'Explicit NativeFormat requires source review before launching an isolated test copy'}
 foreach($item in @(@('git','--version'),@('cmake','--version'),@('ninja','--version'),@('makensis','/VERSION'),@('patch','--version'),@('qmake','-query','QT_VERSION'))){Invoke-RuNative $inventory.tools[$item[0]] ([string[]]@($item|Select-Object -Skip 1)) $nativeLog}
 $qtVersion=(& $inventory.tools.qmake -query QT_VERSION);if($LASTEXITCODE -ne 0 -or $qtVersion -ne '6.9.3'){throw 'This build recipe requires the pinned Qt SDK 6.9.3'}
 New-Item -ItemType Directory -Force $build|Out-Null
 Invoke-RuNative $inventory.tools.cmake @('-S',$source,'-B',$build,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DENABLE_QT6=ON','-DENABLE_IIO=ON','-DRX_SAMPLE_24BIT=ON','-DBUILD_GUI=ON','-DBUILD_SERVER=OFF','-DENABLE_MIRISDR=OFF','-DARCH_OPT=SSE4_2','-DDEBUG_OUTPUT=ON','-DHIDE_CONSOLE=OFF',('-DCMAKE_PREFIX_PATH='+$config.qtRoot+';'+$config.boostRoot),('-DCMAKE_MAKE_PROGRAM='+$inventory.tools.ninja),('-DRU_QT_RU_QM='+$inventory.qtRussianCatalog),('-DCMAKE_INSTALL_PREFIX='+$app)) $nativeLog
 Invoke-RuNative $inventory.tools.cmake @('--build',$build,'--config','Release','--parallel',[string]$config.parallel,'--target','package') $nativeLog
 $status.compiled=$true
 Invoke-RuNative $inventory.tools.cmake @('--install',$build,'--config','Release','--prefix',$app) $nativeLog
 $exe=Join-Path $app 'sdrangel.exe';if(-not (Test-Path -LiteralPath $exe)){throw 'Installed test executable missing'}
 Invoke-RuNative $inventory.tools.windeployqt @('--release','--compiler-runtime','--qmldir',$source,$exe) $nativeLog
 foreach($file in @('sdrangel.exe','libiio.dll','plugins\inputplutosdr.dll','plugins\mimoplutosdr.dll','translations\sdrangel_ru.qm','translations\qt_ru.qm')){if(-not (Test-Path -LiteralPath (Join-Path $app $file))){throw "Portable test distribution missing: $file"}}
 [ordered]@{built=$true;isolatedSettingsBootstrapped=$true;version='7.27.2';commit=$head;fullTranslationComplete=$coverage.complete;guiTested=$false;hardwareTested=$false;executable=$exe;executableSha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash}|ConvertTo-Json|Set-Content (Join-Path $root 'logs\build-artifact.json') -Encoding UTF8
 $status.portableAppPrepared=$true;$status.success=$true
 Write-Host 'Separate test build prepared. No GUI or radio was started. Visual/hardware validation still required.'
} catch {
 $status.error=$_.Exception.Message
 $_|Out-String|Set-Content (Join-Path $run 'error.txt') -Encoding UTF8
 Write-Host ('FAILED: '+$status.error) -ForegroundColor Red
 exit 1
} finally {
 $status|ConvertTo-Json -Depth 5|Set-Content (Join-Path $root 'logs\build-last.json') -Encoding UTF8
 $status|ConvertTo-Json -Depth 5|Set-Content (Join-Path $run 'result.json') -Encoding UTF8
 Stop-Transcript|Out-Null
}
