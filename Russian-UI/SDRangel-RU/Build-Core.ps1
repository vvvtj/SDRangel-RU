$ErrorActionPreference='Stop'
function Resolve-RuTool([string]$name) {
 if(Test-Path -LiteralPath $name -PathType Leaf){return (Resolve-Path -LiteralPath $name).Path}
 $command=Get-Command $name -ErrorAction SilentlyContinue
 if($command){return $command.Source}
 return $null
}
function Get-RuInventory($config,[string]$root) {
 $tools=[ordered]@{}
 foreach($name in @('git','cmake','ninja','makensis','patch')){$tools[$name]=Resolve-RuTool $config.$name}
 $tools['cl']=Resolve-RuTool 'cl.exe'
 foreach($name in @('qmake','lupdate','lrelease','windeployqt')){$tools[$name]=Resolve-RuTool (Join-Path $config.qtRoot ('bin\'+$name+'.exe'))}
 $modules=@('Core','Widgets','Network','WebSockets','Multimedia','MultimediaWidgets','Positioning','Charts','SerialPort','OpenGL','OpenGLWidgets','Quick','QuickWidgets','Svg','SvgWidgets','StateMachine','Core5Compat','WebChannel','WebEngineCore','WebEngineWidgets','WebEngineQuick','TextToSpeech','Location','LinguistTools','ShaderTools')
 $moduleResults=@($modules|ForEach-Object {[pscustomobject]@{module=$_;found=(Test-Path -LiteralPath (Join-Path $config.qtRoot ('lib\cmake\Qt6'+$_+'\Qt6'+$_+'Config.cmake')))}})
 [string]$qtRu=@((Join-Path $config.qtRoot 'translations\qt_ru.qm'),(Join-Path (Split-Path $config.qtRoot -Parent) 'translations\qt_ru.qm'))|Where-Object {Test-Path -LiteralPath $_}|Select-Object -First 1
 $missing=New-Object Collections.Generic.List[string]
 foreach($name in $tools.Keys){if(-not $tools[$name]){$missing.Add($name)}}
 foreach($module in $moduleResults){if(-not $module.found){$missing.Add('Qt6'+$module.module)}}
 if(-not (Test-Path -LiteralPath (Join-Path $config.boostRoot 'boost\version.hpp'))){$missing.Add('Boost headers 1.73.0')}
 if(-not $qtRu){$missing.Add('Qt qt_ru.qm')}
 $sdkRoots=@('C:\Program Files (x86)\Windows Kits\10\Include','C:\Program Files\Windows Kits\10\Include')
 $sdkFound=@($sdkRoots|Where-Object {Test-Path -LiteralPath $_}).Count -gt 0
 if(-not $sdkFound){$missing.Add('Windows 10/11 SDK (standard paths)')}
 $mfcFound=$false
 if($env:VCToolsInstallDir){$mfcFound=Test-Path -LiteralPath (Join-Path $env:VCToolsInstallDir 'atlmfc\include\afxwin.h')}
 if(-not $mfcFound){$missing.Add('MSVC v143 MFC headers (x64 development environment)')}
 $vswhere='C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
 $vsFound=Test-Path -LiteralPath $vswhere
 $source=Join-Path $root 'source'
 $checkoutFound=Test-Path -LiteralPath (Join-Path $source '.git')
 $submoduleFound=Test-Path -LiteralPath (Join-Path $source 'external\windows\.git')
 [pscustomobject]@{timestampUtc=[DateTime]::UtcNow.ToString('o');tools=$tools;qtModules=$moduleResults;qtRoot=$config.qtRoot;qtRussianCatalog=$qtRu;boostRoot=$config.boostRoot;visualStudioLocatorFound=$vsFound;windowsSdkFound=$sdkFound;mfcHeadersFound=$mfcFound;fullCheckoutPresent=$checkoutFound;windowsLibrariesPresent=$submoduleFound;missingToolsAndModules=@($missing);readyToBuild=($missing.Count -eq 0 -and $checkoutFound -and $submoduleFound);installedRuntimeQtVersion=(Get-Item 'C:\Program Files\SDRangel\Qt6Core.dll' -ErrorAction SilentlyContinue).VersionInfo.FileVersion;actualCompilationTested=$false;guiRenderingTested=$false;hardwareTested=$false}
}
function Invoke-RuNative([string]$exe,[string[]]$arguments,[string]$log) {
 [pscustomobject]@{executable=$exe;arguments=$arguments;timestampUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Compress|Add-Content ($log+'.commands.jsonl') -Encoding UTF8
 $oldPreference=$ErrorActionPreference
 try{$ErrorActionPreference='Continue'; & $exe @arguments 2>&1|Tee-Object -FilePath $log -Append|Out-Host; $code=$LASTEXITCODE}finally{$ErrorActionPreference=$oldPreference}
 if($code -ne 0){throw "Native command failed ($code): $exe; see $log"}
}
function Assert-RuPath([string]$path,[string]$root) {
 $resolved=[IO.Path]::GetFullPath($path)
 $prefix=[IO.Path]::GetFullPath($root).TrimEnd('\')+'\'
 if(-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Path outside SDRangel-RU: $resolved"}
 return $resolved
}
function Add-RuCMakeIntegration([string]$source,[string]$backup) {
 $path=Join-Path $source 'CMakeLists.txt';$text=[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
 if($text.Contains('# SDRANGEL_RU_GUI_CATALOG_BEGIN')){return}
 Copy-Item -LiteralPath $path -Destination (Join-Path $backup 'CMakeLists.txt')
 $block=@'

# SDRANGEL_RU_GUI_CATALOG_BEGIN
if(BUILD_GUI AND ENABLE_QT6)
  find_package(Qt6 REQUIRED COMPONENTS LinguistTools)
  set(RU_TS "${CMAKE_SOURCE_DIR}/translations/sdrangel_ru.ts")
  set(RU_QM "${CMAKE_CURRENT_BINARY_DIR}/translations/sdrangel_ru.qm")
  if(NOT EXISTS "${RU_QT_RU_QM}")
    message(FATAL_ERROR "RU_QT_RU_QM must point to the Qt Russian catalog")
  endif()
  get_filename_component(RU_QT_TRANSLATIONS_DIR "${RU_QT_RU_QM}" DIRECTORY)
  file(GLOB RU_QT_RUSSIAN_CATALOGS "${RU_QT_TRANSLATIONS_DIR}/*_ru.qm")
  add_custom_command(OUTPUT "${RU_QM}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/translations"
    COMMAND $<TARGET_FILE:Qt6::lrelease> "${RU_TS}" -nounfinished -qm "${RU_QM}"
    DEPENDS "${RU_TS}" VERBATIM)
  add_custom_target(sdrangel_ru_catalog ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory "${SDRANGEL_BINARY_BIN_DIR}/translations"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${RU_QM}" "${SDRANGEL_BINARY_BIN_DIR}/translations/sdrangel_ru.qm"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${RU_QT_RUSSIAN_CATALOGS} "${SDRANGEL_BINARY_BIN_DIR}/translations"
    DEPENDS "${RU_QM}" VERBATIM)
  add_dependencies(sdrangel sdrangel_ru_catalog)
  add_custom_command(TARGET sdrangel POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:sdrangel>/translations"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${RU_QM}" "$<TARGET_FILE_DIR:sdrangel>/translations/sdrangel_ru.qm"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${RU_QT_RUSSIAN_CATALOGS} "$<TARGET_FILE_DIR:sdrangel>/translations"
    VERBATIM)
  install(FILES "${RU_QM}" ${RU_QT_RUSSIAN_CATALOGS} DESTINATION "translations")
endif()
# SDRANGEL_RU_GUI_CATALOG_END
'@
 [IO.File]::WriteAllText($path,$text+"`n"+$block+"`n",(New-Object Text.UTF8Encoding $false))
}
