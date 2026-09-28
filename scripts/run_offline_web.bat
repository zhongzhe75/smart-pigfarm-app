@echo off
setlocal

where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python was not found. Install Python 3 and ensure python is on PATH.
  exit /b 1
)

set "WEB_ROOT=D:\Abox\smart_pigfarm_web_local"

if not exist "%WEB_ROOT%\index.html" (
  echo [ERROR] %WEB_ROOT% was not found. Build and copy the Web local edition first.
  echo flutter build web --release --dart-define=APP_RUNTIME_MODE=webLocal
  exit /b 1
)

echo Offline Web is available at http://localhost:8080
python -m http.server 8080 --directory "%WEB_ROOT%"
