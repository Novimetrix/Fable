@echo off
REM RUN-FIX-ULTRA2-HTMLONLY-CLOSE.cmd — closes when you press Enter
setlocal
set "HERE=%~dp0"
set "PS1=%HERE%mojibake-fixer-ULTRA2-HTMLONLY.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS1%" (
  echo PowerShell file not found: "%PS1%"
  pause
  exit /b 1
)
REM No -NoExit here, so the window will close after the script exits.
"%PS%" -ExecutionPolicy Bypass -File "%PS1%"
