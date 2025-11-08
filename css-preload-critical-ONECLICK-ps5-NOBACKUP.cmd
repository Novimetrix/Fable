@echo off
REM css-preload-critical-ONECLICK-ps5-NOBACKUP.cmd (CSS+fonts only)
setlocal
set SCRIPT=%~dp0css-preload-critical-ONECLICK-ps5-NOBACKUP.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set EC=%ERRORLEVEL%
if not "%EC%"=="0" (
  echo.
  echo AN ERROR OCCURRED! Exit code: %EC%
  echo Run directly to see details:
  echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
  pause
)
endlocal
