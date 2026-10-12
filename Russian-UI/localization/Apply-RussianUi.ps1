[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference='Stop'
$seed=Join-Path $PSScriptRoot 'sdrangel_ru.ts'
if(-not (Test-Path -LiteralPath $seed)){throw 'Generate and validate sdrangel_ru.ts before applying the source patch'}
[xml]$validatedCatalog=[IO.File]::ReadAllText($seed,[Text.Encoding]::UTF8)
$workspace=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')+'\'
$source=[IO.Path]::GetFullPath($SourceRoot).TrimEnd('\')+'\'
if(-not $source.StartsWith($workspace,[StringComparison]::OrdinalIgnoreCase)){throw 'Source checkout must be inside the project workspace'}
$main=Join-Path $source 'app\main.cpp'
$text=[IO.File]::ReadAllText($main,[Text.Encoding]::UTF8)
if($text.Contains('UiLanguageBootstrap')){throw 'Source is already patched; original backup is retained'}
foreach($anchor in @('#include <QApplication>','QSettings settings;','SDRangelApplication a(argc, argv);','MainWindow w(logger, parser);')){if(([regex]::Matches($text,[regex]::Escape($anchor))).Count -ne 1){throw "Unexpected source/version: $anchor"}}
$backup=Join-Path $workspace ('SDRangelBackups\ui-language-'+(Get-Date -Format yyyyMMdd-HHmmss-fff))
New-Item -ItemType Directory -Force $backup|Out-Null
Copy-Item -LiteralPath $main -Destination (Join-Path $backup 'main.cpp')
$header=Join-Path $source 'app\UiLanguageBootstrap.h'
if(Test-Path $header){Copy-Item $header (Join-Path $backup 'UiLanguageBootstrap.h')}
$text=$text.Replace('#include <QApplication>','#include <QApplication>' + "`n" + '#include "UiLanguageBootstrap.h"')
$text=$text.Replace('QSettings settings;','UiLanguageBootstrap::initializeSettingsStorage();' + "`n    QSettings settings;")
$text=$text.Replace('SDRangelApplication a(argc, argv);','SDRangelApplication a(argc, argv);' + "`n    UiLanguageBootstrap::initialize(a);")
$text=$text.Replace('MainWindow w(logger, parser);','MainWindow w(logger, parser);' + "`n    UiLanguageBootstrap::attachMenu(w);")
# BOM makes Cyrillic source unambiguous for MSVC without changing global compiler flags.
[IO.File]::WriteAllText($header,[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'UiLanguageBootstrap.h')),(New-Object Text.UTF8Encoding $true))
[IO.File]::WriteAllText($main,$text,(New-Object Text.UTF8Encoding $true))
$translations=Join-Path $source 'translations';New-Item -ItemType Directory -Force $translations|Out-Null
$catalog=Join-Path $translations 'sdrangel_ru.ts'
if(Test-Path $catalog){Copy-Item $catalog (Join-Path $backup 'sdrangel_ru.ts')}
Copy-Item (Join-Path $PSScriptRoot 'sdrangel_ru.ts') $catalog
Write-Host "GUI-only source patch applied. Backup: $backup"
Write-Host 'This does not rebuild or translate the installed SDRangel executable.'
