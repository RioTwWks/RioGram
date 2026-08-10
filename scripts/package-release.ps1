# Упаковка Windows-сборки для релиза.
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$OutputDir
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$SourceDir = Join-Path $RootDir "build\windows\x64\runner\Release"
$Archive = Join-Path $OutputDir "RioGram-$Version-windows-x64.zip"

if (-not (Test-Path $SourceDir)) {
    throw "Каталог сборки не найден: $SourceDir"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (Test-Path $Archive) { Remove-Item $Archive }

Compress-Archive -Path (Join-Path $SourceDir "*") -DestinationPath $Archive -Force
Write-Host "✅ Пакет windows → $Archive"
