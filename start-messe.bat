@echo off
rem ============================================================
rem  e-Rezept Jump'n'Run — Messestart (Kiosk-Modus)
rem  Voraussetzung: npm run build wurde einmal ausgefuehrt (dist/)
rem ============================================================
setlocal
set "NODEDIR=%~dp0.tools\node"
set "PATH=%NODEDIR%;%PATH%"

rem Lokaler Mini-Server fuer dist/ (offline, Port 8080)
start "erezept-server" /min "%NODEDIR%\node.exe" "%~dp0tools\serve.mjs"

rem Kurz warten, bis der Server steht
timeout /t 2 /nobreak >nul

rem Chrome im Kiosk-Vollbild (ohne --app, siehe Konzept)
start "" chrome --kiosk "http://127.0.0.1:8080/?kiosk=1" --noerrdialogs --disable-pinch --overscroll-history-navigation=0 --autoplay-policy=no-user-gesture-required --disable-session-crashed-bubble

endlocal
