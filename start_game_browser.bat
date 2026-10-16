@echo off
echo ========================================================
echo   Trading Game - Starte im Google Chrome Browser...
echo ========================================================
cd /d "%~dp0"
flutter run -d chrome --web-port=8088 --web-hostname=localhost
pause
