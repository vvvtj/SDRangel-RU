[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Lrelease,[Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
if(-not (Test-Path -LiteralPath $Lrelease)){throw 'Qt lrelease is missing; no QM catalog built'}
New-Item -ItemType Directory -Force $OutputDirectory|Out-Null
& $Lrelease (Join-Path $PSScriptRoot 'sdrangel_ru.ts') -qm (Join-Path $OutputDirectory 'sdrangel_ru.qm')
if($LASTEXITCODE -ne 0){throw 'lrelease failed'}
