$ErrorActionPreference='Stop'
$path=Join-Path $PSScriptRoot 'sdrangel_ru.ts'
$bytes=[IO.File]::ReadAllBytes($path);$strict=New-Object Text.UTF8Encoding $false,$true;$text=$strict.GetString($bytes)
[xml]$xml=$text
$forbidden=@('deviceHwType','direction','uri','centerFrequency','rxCenterFrequency','devSampleRate','lpfBW','lpfBWRx','rx0Gain','rx1Gain','gainMode','plutoSdrMIMOSettings')
$count=0
foreach($context in $xml.TS.context) {
 $seen=@{}
 foreach($message in $context.message) {
  $source=[string]$message.source;$translation=[string]$message.translation
  if($seen.ContainsKey($source)){throw 'Duplicate TS key'};$seen[$source]=$true
  if($forbidden -ccontains $source){throw 'Technical key in translation catalog'}
  $a=@([regex]::Matches($source,'%\d+|%n')|ForEach-Object Value|Sort-Object)
  $b=@([regex]::Matches($translation,'%\d+|%n')|ForEach-Object Value|Sort-Object)
  if(($a -join ',') -ne ($b -join ',')){throw 'Translation placeholder mismatch'}
  if($translation.Contains([char]0xfffd)){throw 'UTF-8 replacement character'}
  $count++
 }
}
if($text -notmatch 'Частота' -or $text -notmatch 'Водопад'){throw 'Missing Cyrillic text'}
$header=Get-Content (Join-Path $PSScriptRoot 'UiLanguageBootstrap.h') -Raw -Encoding UTF8
foreach($term in @('libiio','MainCore','DSP')) {# Only the header comment may mention these; no includes/dependencies.
 if($header -match ('#include.*'+$term)){throw 'Backend dependency in UI-only patch'}
}
$report=[ordered]@{catalogUtf8=$true;xmlValid=$true;placeholdersPreserved=$true;technicalKeysUnchanged=$true;messages=$count;qtCompilationTested=$false;guiCyrillicTested=$false;guiClippingTested=$false;fullTranslationComplete=$false}
$report|ConvertTo-Json|Set-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'logs\localization-tests.json') -Encoding UTF8
Write-Host "PASS: $count seed messages, UTF-8/XML, placeholders and technical-key protection. Qt GUI compilation/rendering not tested."
