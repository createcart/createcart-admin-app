# Build + install CreateCart Admin on the attached Android phone.
# Sets JDK 17 + Flutter on PATH, builds a release APK, installs it.
#
# Usage:
#   ./build.ps1                 builds the "prod" flavor (talks to the live API)
#   ./build.ps1 -Local           builds "local" (installs alongside prod; needs
#                                 -ApiBase, e.g. http://localhost:8000 via
#                                 `adb reverse tcp:8000 tcp:8000` for a real device)
param(
    [switch]$Local,
    [string]$ApiBase = "http://localhost:8000"
)
$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "D:\jdk17\jdk-17.0.19+10"
$env:Path = "C:\src\flutter\bin;$env:JAVA_HOME\bin;C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools;$env:Path"

Set-Location $PSScriptRoot

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

$flavor = if ($Local) { "local" } else { "prod" }
Write-Host "==> building release APK (flavor: $flavor)" -ForegroundColor Cyan
if ($Local) {
    flutter build apk --release --flavor local "--dart-define=API_BASE=$ApiBase"
} else {
    flutter build apk --release --flavor prod
}

$apk = "build\app\outputs\flutter-apk\app-$flavor-release.apk"
if (-not (Test-Path $apk)) { throw "APK not found at $apk" }
Write-Host "Built $apk" -ForegroundColor Green

$devices = (adb devices | Select-String "device$")
if (-not $devices) {
    Write-Host "No device attached. Connect your phone (USB debugging) and run: adb install -r $apk" -ForegroundColor Yellow
    exit 0
}

if ($Local) {
    Write-Host "==> adb reverse tcp:8000 tcp:8000 (phone's localhost:8000 -> this PC)" -ForegroundColor Cyan
    adb reverse tcp:8000 tcp:8000
}

Write-Host "==> installing on phone" -ForegroundColor Cyan
adb install -r $apk
$label = if ($Local) { "CreateCart Admin (Local)" } else { "CreateCart Admin" }
Write-Host "Done. Launch '$label' on your phone." -ForegroundColor Green
