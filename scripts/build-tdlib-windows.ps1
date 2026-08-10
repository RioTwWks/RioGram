# Сборка TDLib для Windows (MSVC + vcpkg OpenSSL).
param(
    [string]$VcpkgRoot = $(if ($env:VCPKG_INSTALLATION_ROOT) { $env:VCPKG_INSTALLATION_ROOT } else { $env:VCPKG_ROOT })
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $RootDir "td\build"

if (-not $VcpkgRoot) {
    throw "VCPKG_INSTALLATION_ROOT не задан. Установите vcpkg и экспортируйте переменную."
}

if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

Push-Location $BuildDir
try {
    $toolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
  cmake -A x64 `
    -DCMAKE_BUILD_TYPE=Release `
    -DTD_ENABLE_LTO=OFF `
    -DCMAKE_TOOLCHAIN_FILE="$toolchain" `
    -DCMAKE_INSTALL_PREFIX="$BuildDir\install" `
    ..

  cmake --build . --config Release --target install --parallel
}
finally {
    Pop-Location
}

$dll = Join-Path $BuildDir "install\bin\tdjson.dll"
if (-not (Test-Path $dll)) {
    $dll = Join-Path $BuildDir "install\lib\tdjson.dll"
}
if (-not (Test-Path $dll)) {
    throw "tdjson.dll не найден после сборки"
}

Write-Host "✅ TDLib собран: $dll"
