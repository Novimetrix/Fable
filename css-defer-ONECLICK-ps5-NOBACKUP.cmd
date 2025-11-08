@echo off
REM css-defer-ONECLICK-ps5-NOBACKUP.cmd
setlocal
set SCRIPT=%~dp0css-defer-ONECLICK-ps5-NOBACKUP.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set EC=%ERRORLEVEL%
if not "%EC%"=="0" (
  echo.
  echo AN ERROR OCCURRED! Exit code: %EC%
  echo If you see no red text above, run this command in PowerShell for details:
  echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
  pause
)
endlocal
