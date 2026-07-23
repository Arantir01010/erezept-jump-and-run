@echo off
rem ============================================================
rem  e-Rezept Jump'n'Run - Level bauen + pruefen (fuer Redaktion)
rem  Kompiliert design/ -> public/ und prueft alles.
rem  Nutzt das mitgelieferte Node aus .tools\node (kein Setup noetig).
rem ============================================================
setlocal
set "NODEDIR=%~dp0.tools\node"
set "PATH=%NODEDIR%;%PATH%"

echo.
echo === Level bauen (design/ -^> public/) ===
"%NODEDIR%\node.exe" "%~dp0node_modules\tsx\dist\cli.mjs" "%~dp0tools\build-levels.ts"
if errorlevel 1 goto fehler

echo.
echo === Komplett-Pruefung ===
"%NODEDIR%\node.exe" "%~dp0node_modules\tsx\dist\cli.mjs" "%~dp0tools\validate-levels.ts"
if errorlevel 1 goto fehler

echo.
echo Alles gruen. Zum Testen: start-spiel.bat (nach "npm run build") oder npm run dev
pause
exit /b 0

:fehler
echo.
echo Es gibt Probleme - bitte die Meldungen oben lesen (Datei + Loesung stehen dabei).
echo Referenz: design\LEVELBAU.md
pause
exit /b 1
