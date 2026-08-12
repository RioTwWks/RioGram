# Сборка TDLib для Windows (MSVC + vcpkg: OpenSSL, zlib).
param(
    [string]$VcpkgRoot = $(if ($env:VCPKG_INSTALLATION_ROOT) { $env:VCPKG_INSTALLATION_ROOT } else { $env:VCPKG_ROOT })
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $RootDir "td\build"

if (-not $VcpkgRoot) {
    throw "VCPKG_INSTALLATION_ROOT не задан. Установите vcpkg и экспортируйте переменную."
}

$Triplet = if ($env:VCPKG_DEFAULT_TRIPLET) { $env:VCPKG_DEFAULT_TRIPLET } else { "x64-windows" }

function Resolve-VcpkgInstalledDir {
    param([string]$ProjectRoot, [string]$VcpkgRootPath)

    if ($env:VCPKG_INSTALLED_DIR) {
        return $env:VCPKG_INSTALLED_DIR
    }

    $manifestDir = Join-Path $ProjectRoot "vcpkg_installed"
    if (Test-Path $manifestDir) {
        return $manifestDir
    }

    return Join-Path $VcpkgRootPath "installed"
}

$VcpkgInstalledDir = Resolve-VcpkgInstalledDir -ProjectRoot $RootDir -VcpkgRootPath $VcpkgRoot
$PrefixPath = Join-Path $VcpkgInstalledDir $Triplet

if (-not (Test-Path $PrefixPath)) {
    throw "vcpkg-пакеты не найдены в $PrefixPath. Запустите vcpkg install (см. vcpkg.json)."
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
        -DVCPKG_MANIFEST_DIR="$RootDir" `
        -DVCPKG_INSTALLED_DIR="$VcpkgInstalledDir" `
        -DCMAKE_PREFIX_PATH="$PrefixPath" `
        -DOPENSSL_ROOT_DIR="$PrefixPath" `
        -DCMAKE_INSTALL_PREFIX="$BuildDir\install" `
        ..
    if ($LASTEXITCODE -ne 0) {
        throw "cmake configure failed with exit code $LASTEXITCODE"
    }

    cmake --build . --config Release --target install --parallel
    if ($LASTEXITCODE -ne 0) {
        throw "cmake build failed with exit code $LASTEXITCODE"
    }
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
