@echo off
rem ============================================================
rem  e-Rezept Jump'n'Run - Commit(s) zu GitHub pushen
rem  Nutzt dein normales Windows-Git (Zugangsdaten sind dort
rem  schon hinterlegt - die bisherigen Pushes kamen von hier).
rem ============================================================
cd /d "%~dp0"
echo.
echo === Push nach GitHub (origin main) ===
git push origin main
if errorlevel 1 (
  echo.
  echo Push fehlgeschlagen. Falls "git" nicht gefunden wurde:
  echo GitHub Desktop oeffnen und dort auf "Push origin" klicken.
) else (
  echo.
  echo Erfolgreich gepusht! GitHub Actions baut das Spiel jetzt automatisch:
  echo https://arantir01010.github.io/erezept-jump-and-run/
  echo (Status: https://github.com/Arantir01010/erezept-jump-and-run/actions)
)
echo.
pause
