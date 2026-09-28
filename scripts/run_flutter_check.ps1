$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter command was not found. Install Flutter SDK and add its bin directory to PATH." -ForegroundColor Red
  Write-Host "Example PATH entry: C:\flutter\bin" -ForegroundColor Yellow
  exit 1
}

Write-Host "== Flutter version ==" -ForegroundColor Cyan
flutter --version

Write-Host "== Ensure platform shells ==" -ForegroundColor Cyan
flutter create . --project-name smart_pigfarm_app --platforms=android,web

Write-Host "== Pub get ==" -ForegroundColor Cyan
flutter pub get

Write-Host "== Analyze ==" -ForegroundColor Cyan
flutter analyze

Write-Host "== Run on Chrome ==" -ForegroundColor Cyan
flutter run -d chrome
