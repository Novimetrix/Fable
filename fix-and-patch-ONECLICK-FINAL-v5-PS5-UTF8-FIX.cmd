@echo off
setlocal
set "HERE=%~dp0"
set "PS1=%HERE%fix-and-patch-ONECLICK-FINAL-v5-PS5-UTF8-FIX.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS1%" (
  echo PowerShell file not found: "%PS1%"
  pause
  exit /b 1
)
"%PS%" -ExecutionPolicy Bypass -File "%PS1%"