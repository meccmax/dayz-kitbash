@echo off
REM -- Kitbash (DayZ gear reskinner) -- local launcher --
REM Serves this folder at http://localhost:8780 and opens it in your browser.
REM Keep this window open while using the tool; close it (or Ctrl+C) to stop.

cd /d "%~dp0"

where python >nul 2>nul
if errorlevel 1 (
  echo.
  echo Python was not found on PATH.
  echo Install Python from https://python.org  ^(or just double-click index.html,
  echo but the UV templates and folder-export will be disabled on file:// ^).
  echo.
  pause
  exit /b 1
)

echo.
echo   Kitbash - DayZ gear reskinner
echo   Running at http://localhost:8780
echo   Keep this window open. Press Ctrl+C or close it to stop.
echo.

start "" http://localhost:8780
python -m http.server 8780
