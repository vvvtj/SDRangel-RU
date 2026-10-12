$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Build-Core.ps1')
$project=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $PSScriptRoot ('logs\test-fixtures-'+(Get-Date -Format yyyyMMdd-HHmmss-fff));New-Item -ItemType Directory -Force $fixture|Out-Null
$utf8=New-Object Text.UTF8Encoding $false
function Require($condition,[string]$message){if(-not $condition){throw $message}}
$actual=@'
<?xml version="1.0" encoding="utf-8"?><TS version="2.1"><context><name>MainWindow</name>
<message><source>File</source><translation type="unfinished"/></message>
<message><source>Remove device set %1?</source><translation type="unfinished"/></message>
<message><source>File</source><comment>different meaning</comment><translation type="unfinished"/></message>
<message numerus="yes"><source>%n samples</source><translation type="unfinished"/></message>
<message><source>Unmatched fixture label</source><translation type="unfinished"/></message>
<message><source>file</source><translation type="unfinished"/></message>
</context><context><name>DifferentContext</name><message><source>File</source><translation type="unfinished"/></message></context></TS>
'@
$extracted=Join-Path $fixture 'extracted-fixture.ts';[IO.File]::WriteAllText($extracted,$actual,$utf8)
$merged=Join-Path $fixture 'merged-fixture.ts'
& (Join-Path $PSScriptRoot 'Merge-Catalog.ps1') -Extracted $extracted -Seed (Join-Path $project 'localization\sdrangel_ru.ts') -Output $merged -ReportDirectory $fixture
[xml]$xml=[IO.File]::ReadAllText($merged,[Text.Encoding]::UTF8)
$messages=@($xml.TS.context[0].message)
Require ($messages[0].SelectSingleNode('translation').GetAttribute('type') -eq '') 'Exact context not accepted'
Require ($messages[1].SelectSingleNode('translation').InnerText -match '%1') 'Placeholder lost'
Require ($messages[2].SelectSingleNode('translation').GetAttribute('type') -eq 'unfinished') 'Disambiguation ignored'
Require ($messages[3].SelectSingleNode('translation').GetAttribute('type') -eq 'unfinished') 'Unreviewed plural accepted'
Require ($messages[4].SelectSingleNode('translation').GetAttribute('type') -eq 'unfinished') 'Missing translation accepted'
Require ($messages[5].SelectSingleNode('translation').InnerText -eq '') 'Case-sensitive source key matched incorrectly'
Require ($xml.TS.context[1].message.SelectSingleNode('translation').GetAttribute('type') -eq 'unfinished') 'Cross-context suggestion treated as exact'
$coverage=Get-Content (Join-Path $fixture 'coverage.json') -Raw -Encoding UTF8|ConvertFrom-Json
Require ($coverage.exactMatches -eq 2 -and $coverage.contextSuggestions -eq 1 -and -not $coverage.complete) 'Coverage count wrong'
$pluralSeed=Join-Path $fixture 'plural-reviewed-fixture.ts'
$pluralSource='<TS version="2.1" language="ru_RU"><context><name>MainWindow</name><message numerus="yes"><source>%n samples</source><translation><numerusform>%n sample A</numerusform><numerusform>%n sample B</numerusform><numerusform>%n sample C</numerusform></translation></message></context></TS>'
[IO.File]::WriteAllText($pluralSeed,$pluralSource,$utf8)
$pluralMerged=Join-Path $fixture 'plural-merged-fixture.ts'
& (Join-Path $PSScriptRoot 'Merge-Catalog.ps1') -Extracted $extracted -Seed $pluralSeed -Output $pluralMerged -ReportDirectory (Join-Path $fixture 'plural-report')
[xml]$pluralXml=[IO.File]::ReadAllText($pluralMerged)
$pluralTranslation=$pluralXml.SelectSingleNode('//message[@numerus="yes"]/translation')
Require ($pluralTranslation.GetAttribute('type') -eq '' -and $pluralTranslation.SelectNodes('numerusform').Count -eq 3) 'Reviewed plural forms were not preserved'
$badSeed=Join-Path $fixture 'bad-placeholder-fixture.ts'
[IO.File]::WriteAllText($badSeed,'<TS><context><name>MainWindow</name><message><source>Remove device set %1?</source><translation>Broken</translation></message></context></TS>',$utf8)
try{& (Join-Path $PSScriptRoot 'Merge-Catalog.ps1') -Extracted $extracted -Seed $badSeed -Output (Join-Path $fixture 'bad.ts') -ReportDirectory $fixture;throw 'Bad placeholder accepted'}catch{if($_.Exception.Message -ne 'Seed placeholder mismatch'){throw}}
try{Assert-RuPath 'C:\Program Files\SDRangel\sdrangel.exe' $PSScriptRoot|Out-Null;throw 'Guard accepted installed directory'}catch{if($_.Exception.Message -notlike 'Path outside SDRangel-RU:*'){throw}}
$source=Join-Path $fixture 'source';$backup=Join-Path $fixture 'backup';New-Item -ItemType Directory -Force (Join-Path $source 'sdrgui'),$backup|Out-Null
$gui=@'
void showLabels() {
    ui->button->setText("File");
    ui->button->setToolTip("Gain");
    ui->button->setObjectName("centerFrequency");
    deviceSettings["centerFrequency"] = 140000000;
    ui->button->setText("Unknown fixture text");
}
'@
$guiPath=Join-Path $source 'sdrgui\mainwindow.cpp';[IO.File]::WriteAllText($guiPath,$gui,$utf8)
& (Join-Path $PSScriptRoot 'Prepare-UiStrings.ps1') -SourceRoot $source -BackupDirectory $backup -ReportDirectory $fixture
$modified=[IO.File]::ReadAllText($guiPath)
Require ($modified.Contains('QCoreApplication::translate("MainWindow", "File")')) 'GUI label not wrapped'
Require ($modified.Contains('setObjectName("centerFrequency")')) 'Technical objectName changed'
Require ($modified.Contains('deviceSettings["centerFrequency"] = 140000000;')) 'Settings key changed'
Require ($modified.Contains('setText("Unknown fixture text")')) 'Unknown literal silently changed'
[IO.File]::WriteAllText((Join-Path $source 'CMakeLists.txt'),'cmake_minimum_required(VERSION 3.16)', $utf8)
Add-RuCMakeIntegration $source $backup
$first=[IO.File]::ReadAllText((Join-Path $source 'CMakeLists.txt'));Add-RuCMakeIntegration $source $backup
Require ($first -eq [IO.File]::ReadAllText((Join-Path $source 'CMakeLists.txt'))) 'CMake integration not idempotent'
Require ($first.Contains('-nounfinished') -and $first.Contains('add_dependencies(sdrangel sdrangel_ru_catalog)')) 'Translation build integration incomplete'
$scripts=@(Get-ChildItem $PSScriptRoot -Filter *.ps1)+@(Get-ChildItem (Join-Path $project 'localization') -Filter *.ps1)
foreach($script in $scripts){$tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)|Out-Null;Require ($errors.Count -eq 0) ('PowerShell syntax: '+$script.Name)}
[ordered]@{passed=$true;syntheticFixtures=$true;exactContextMatching=$true;disambiguationProtected=$true;crossContextSuggestionsUnfinished=$true;placeholdersPreserved=$true;technicalKeysUnchanged=$true;installedDirectoryRejected=$true;cmakeIntegrationIdempotent=$true;actualLupdateTested=$false;actualQtCompilationTested=$false;guiRenderingTested=$false;fixtureDirectory=$fixture}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'logs\workflow-tests.json') -Encoding UTF8
Write-Host 'PASS: merge/disambiguation/placeholders, GUI-only literal edits, path guards, CMake idempotence and PowerShell syntax. No Qt compilation or real source extraction tested.'
