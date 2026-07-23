@echo off
rem ============================================================
rem  e-Rezept Jump'n'Run - Spiel ausprobieren (OHNE Kiosk-Modus)
rem  Startet den lokalen Mini-Server und oeffnet den Browser.
rem  Beenden: Browser-Tab schliessen + minimiertes Serverfenster schliessen.
rem ============================================================
setlocal
set "NODEDIR=%~dp0.tools\node"

rem Lokaler Mini-Server fuer dist/ (offline, Port 8080) - falls er schon
rem laeuft, beendet sich der zweite Start einfach von selbst.
start "erezept-server" /min "%NODEDIR%\node.exe" "%~dp0tools\serve.mjs"

rem Kurz warten, bis der Server steht
timeout /t 2 /nobreak >nul

rem Standardbrowser im normalen Fenster (Steuerung: Pfeile/WASD, Leertaste, E)
start "" http://127.0.0.1:8080/

endlocal
