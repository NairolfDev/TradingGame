@echo off
echo ========================================================
echo   Trading Game - Lokaler Web-Server (Port 8088)
echo ========================================================
cd /d "%~dp0"
start http://localhost:8088
python -m http.server 8088 --directory build/web
pause
