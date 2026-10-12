[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SourceRoot,[Parameter(Mandatory=$true)][string]$BackupDirectory,[Parameter(Mandatory=$true)][string]$ReportDirectory)
$ErrorActionPreference='Stop'
[xml]$seed=[IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'localization\sdrangel_ru.ts'),[Text.Encoding]::UTF8)
$known=[Collections.Hashtable]::new([StringComparer]::Ordinal);foreach($context in $seed.TS.context){foreach($message in $context.message){$known[[string]$message.source]=$true}}
$files=[ordered]@{'sdrgui/mainwindow.cpp'='MainWindow';'sdrgui/gui/glspectrumgui.cpp'='GLSpectrumGUI';'sdrgui/gui/spectrumgui.cpp'='SpectrumGUI';'plugins/samplesource/plutosdrinput/plutosdrinputgui.cpp'='PlutoSDRInputGUI';'plugins/samplemimo/plutosdrmimo/plutosdrmimogui.cpp'='PlutoSDRMIMOGUI'}
$rows=New-Object Collections.Generic.List[object]
# Only direct literals in presentation setters, in five explicitly listed GUI files.
# Never edit settings, drivers, DSP, API files or addItem/user-data values.
$pattern='(?<prefix>(?:->|\.)(?:setText|setToolTip|setStatusTip|setWindowTitle|addMenu|addAction)\s*\(\s*)(?<literal>"(?:[^"\\]|\\.)*")(?<suffix>\s*\))'
foreach($relative in $files.Keys){
 $path=Join-Path $SourceRoot $relative;if(-not (Test-Path -LiteralPath $path)){continue}
 $context=$files[$relative];$text=[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
 $updated=[regex]::Replace($text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($match)
  $literal=$match.Groups['literal'].Value;$english=$literal.Substring(1,$literal.Length-2)
  $review= -not $known.ContainsKey($english)
  $rows.Add([pscustomobject]@{file=$relative;context=$context;source=$english;wrapped=(-not $review);manualReview=$review})
  if($review){return $match.Value}
  return $match.Groups['prefix'].Value+'QCoreApplication::translate("'+$context+'", '+$literal+')'+$match.Groups['suffix'].Value
 })
 if($updated -ne $text){
  $destination=Join-Path $BackupDirectory ($relative.Replace('/','_'));Copy-Item -LiteralPath $path -Destination $destination
  if(-not $updated.Contains('#include <QCoreApplication>')){$updated='#include <QCoreApplication>'+"`n"+$updated}
  [IO.File]::WriteAllText($path,$updated,(New-Object Text.UTF8Encoding $false))
 }
}
New-Item -ItemType Directory -Force $ReportDirectory|Out-Null
$rows|Export-Csv (Join-Path $ReportDirectory 'gui-literal-review.csv') -NoTypeInformation -Encoding UTF8
Write-Output ('Presentation literals wrapped: '+@($rows|Where-Object wrapped).Count+'; other literals need review: '+@($rows|Where-Object manualReview).Count)
