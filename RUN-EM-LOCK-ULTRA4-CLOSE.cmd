@echo off
REM RUN-EM-LOCK-ULTRA4-CLOSE.cmd — stronger lock; closes on Enter
setlocal
set "HERE=%~dp0"
set "PS1=%HERE%em-lock-ULTRA4.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS1%" (
  echo PowerShell file not found: "%PS1%"
  pause
  exit /b 1
)
"%PS%" -ExecutionPolicy Bypass -File "%PS1%"
