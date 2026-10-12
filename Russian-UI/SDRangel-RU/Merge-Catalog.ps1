[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Extracted,[Parameter(Mandatory=$true)][string]$Seed,[Parameter(Mandatory=$true)][string]$Output,[Parameter(Mandatory=$true)][string]$ReportDirectory)
$ErrorActionPreference='Stop'
$utf8=New-Object Text.UTF8Encoding $false,$true
[xml]$actual=$utf8.GetString([IO.File]::ReadAllBytes($Extracted))
[xml]$preliminary=$utf8.GetString([IO.File]::ReadAllBytes($Seed))
function Key($context,$message){([string]$context)+[char]0x1f+([string]$message.source)+[char]0x1f+([string]$message.comment)+[char]0x1f+([string]$message.GetAttribute('numerus'))}
function Placeholders($value){(@([regex]::Matches($value,'%L?\d+|%n')|ForEach-Object Value|Sort-Object) -join '|')}
$exact=[Collections.Hashtable]::new([StringComparer]::Ordinal)
$bySource=[Collections.Hashtable]::new([StringComparer]::Ordinal)
$used=[Collections.Hashtable]::new([StringComparer]::Ordinal)
$pluralExact=[Collections.Hashtable]::new([StringComparer]::Ordinal)
$rows=New-Object Collections.Generic.List[object]
foreach($context in $preliminary.TS.context){foreach($message in $context.message){
 $translationNode=$message.SelectSingleNode('translation')
 if(-not $translationNode){continue}
 $translation=$translationNode.InnerText
 if(-not $translation -or $translationNode.GetAttribute('type') -in @('unfinished','obsolete','vanished')){continue}
 $key=Key $context.name $message
 if($message.GetAttribute('numerus') -eq 'yes'){
  $forms=@($translationNode.SelectNodes('numerusform'))
  if($forms.Count -ne 3){throw 'Reviewed Russian plural must have three forms'}
  foreach($form in $forms){if(-not $form.InnerText -or (Placeholders ([string]$message.source)) -ne (Placeholders $form.InnerText)){throw 'Plural placeholder mismatch'}}
  if($pluralExact.ContainsKey($key)){throw 'Duplicate plural seed key'}
  $pluralExact[$key]=$translationNode;continue
 }
 if((Placeholders ([string]$message.source)) -ne (Placeholders $translation)){throw 'Seed placeholder mismatch'}
 if($exact.ContainsKey($key)){throw 'Duplicate seed context/source/comment key'}
 $exact[$key]=$translation
 $sourceKey=([string]$message.source)+[char]0x1f+([string]$message.comment)
 if(-not $bySource.ContainsKey($sourceKey)){$bySource[$sourceKey]=New-Object Collections.Generic.List[string]}
 if(-not $bySource[$sourceKey].Contains($translation)){$bySource[$sourceKey].Add($translation)}
}}
$total=0;$matched=0;$suggested=0;$missing=0
foreach($context in $actual.TS.context){foreach($message in $context.message){
 $total++;$key=Key $context.name $message;$translation=$message.SelectSingleNode('translation')
 if(-not $translation){$translation=$actual.CreateElement('translation');[void]$message.AppendChild($translation)}
 $status='missing';$candidate=''
 if($message.GetAttribute('numerus') -eq 'yes'){
  if($pluralExact.ContainsKey($key)){
   $replacement=$actual.ImportNode($pluralExact[$key],$true);[void]$message.ReplaceChild($replacement,$translation);$translation=$replacement
   $candidate=$translation.InnerText;$status='exact';$matched++;$used[$key]=$true
  }else{$status='plural-review';$missing++}
 }
 elseif($exact.ContainsKey($key)){$candidate=$exact[$key];$translation.InnerText=$candidate;$translation.RemoveAttribute('type');$status='exact';$matched++;$used[$key]=$true}
 else {
  $sourceKey=([string]$message.source)+[char]0x1f+([string]$message.comment)
  if($bySource.ContainsKey($sourceKey) -and $bySource[$sourceKey].Count -eq 1){$candidate=$bySource[$sourceKey][0];$translation.InnerText=$candidate;$status='context-review';$suggested++}else{$translation.InnerText='';$missing++}
 }
 if($status -ne 'exact'){$translation.SetAttribute('type','unfinished')}
 if($candidate -and $message.GetAttribute('numerus') -ne 'yes' -and ((Placeholders ([string]$message.source)) -ne (Placeholders $candidate))){throw 'Merged placeholder mismatch'}
 $rows.Add([pscustomobject]@{context=[string]$context.name;source=[string]$message.source;comment=[string]$message.comment;status=$status;translation=$candidate;locations=(@($message.location|ForEach-Object {([string]$_.filename)+':'+([string]$_.line)}) -join ';')})
}}
$actual.TS.SetAttribute('language','ru_RU');$actual.TS.SetAttribute('sourcelanguage','en_US')
New-Item -ItemType Directory -Force $ReportDirectory|Out-Null
$settings=New-Object Xml.XmlWriterSettings;$settings.Encoding=New-Object Text.UTF8Encoding $false;$settings.Indent=$true
$writer=[Xml.XmlWriter]::Create($Output,$settings);try{$actual.Save($writer)}finally{$writer.Dispose()}
$rows|Export-Csv (Join-Path $ReportDirectory 'coverage.csv') -NoTypeInformation -Encoding UTF8
$rows|Where-Object status -ne 'exact'|Export-Csv (Join-Path $ReportDirectory 'translation-review.csv') -NoTypeInformation -Encoding UTF8
$unused=@(@($exact.Keys)+@($pluralExact.Keys)|Where-Object {-not $used.ContainsKey($_)}|Sort-Object)
$unused|Set-Content (Join-Path $ReportDirectory 'unused-seed-keys.txt') -Encoding UTF8
$contexts=@($rows|Group-Object context|ForEach-Object {[pscustomobject]@{context=$_.Name;total=$_.Count;translated=@($_.Group|Where-Object status -eq 'exact').Count}})
$report=[ordered]@{realMessages=$total;exactMatches=$matched;contextSuggestions=$suggested;missingOrPluralReview=$missing;unusedSeedEntries=$unused.Count;complete=($total -gt 0 -and $matched -eq $total);sourceExtractionProvided=$true;contexts=$contexts;note='Suggestions are unfinished and excluded by lrelease -nounfinished. Extraction does not cover hardcoded text lacking tr().' }
$report|ConvertTo-Json -Depth 6|Set-Content (Join-Path $ReportDirectory 'coverage.json') -Encoding UTF8
Write-Output "Real strings: $total; exact: $matched; context review: $suggested; missing/plural: $missing"
