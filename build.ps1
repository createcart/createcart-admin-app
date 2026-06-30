# Build + install CreateCart Admin on the attached Android phone.
# Sets JDK 17 + Flutter on PATH, builds a release APK, installs it.
$ErrorActionPreference = "Stop"

$env:JAVA_HOME = "D:\jdk17\jdk-17.0.19+10"
$env:Path = "C:\src\flutter\bin;$env:JAVA_HOME\bin;C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools;$env:Path"

Set-Location $PSScriptRoot

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

Write-Host "==> building release APK" -ForegroundColor Cyan
flutter build apk --release

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apk)) { throw "APK not found at $apk" }
Write-Host "Built $apk" -ForegroundColor Green

$devices = (adb devices | Select-String "device$")
if (-not $devices) {
    Write-Host "No device attached. Connect your phone (USB debugging) and run: adb install -r $apk" -ForegroundColor Yellow
    exit 0
}

Write-Host "==> installing on phone" -ForegroundColor Cyan
adb install -r $apk
Write-Host "Done. Launch 'CreateCart Admin' on your phone." -ForegroundColor Green
