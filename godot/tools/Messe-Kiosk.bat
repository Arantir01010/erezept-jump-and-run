@echo off
rem Paul & REZI - Messe-Kiosk mit automatischem Neustart.
rem Liegt nach tools\build.ps1 im Ordner build\. Startet das Spiel im Kiosk-Modus
rem (Vollbild, Idle-Reset, F11/F12/Alt+F4 gesperrt) und startet es nach einem
rem Absturz oder Beenden nach 3 Sekunden neu.
rem Beenden fuer das Standpersonal: im Spiel Strg+Umschalt+F12 (kein Neustart).
rem Lautstaerke im Spiel: Strg+F9 leiser, Strg+F10 lauter.
cd /d "%~dp0"
title Paul und REZI - Messe-Kiosk
rem Energiesparen/Bildschirmschoner, Updates und Benachrichtigungen vorher am
rem Messe-PC abschalten (siehe godot/README.md, Abschnitt Messe-Kiosk).
:loop
echo %date% %time% Start >> kiosk-neustarts.log
start "" /wait "Godot_v4.7.2-stable_win64.exe" --main-pack "PaulUndRezi.pck" -- --kiosk
set CODE=%errorlevel%
echo %date% %time% Ende (Code %CODE%) >> kiosk-neustarts.log
if "%CODE%"=="7" goto ende
timeout /t 3 >nul
goto loop
:ende
