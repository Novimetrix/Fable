@echo off
REM EM-LOCK-DIAG.cmd — injects a small floating panel that displays computed font sizes
setlocal
set "HERE=%~dp0"
set "PS1=%HERE%EM-LOCK-DIAG.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS1%" (
  echo PowerShell file not found: "%PS1%"
  pause
  exit /b 1
)
"%PS%" -ExecutionPolicy Bypass -File "%PS1%"
