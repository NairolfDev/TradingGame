@echo off
echo ========================================================
echo   Trading Game - Starte auf Windows Desktop...
echo ========================================================
cd /d "%~dp0"
REM Google-Login auf Windows braucht dart_defines.local.json (nicht im Git)
if exist dart_defines.local.json (
  flutter run -d windows --dart-define-from-file=dart_defines.local.json
) else (
  flutter run -d windows
)
pause
