@echo off
REM EMDASH-LOCK-v1.cmd — run patch to normalize em‑dash width
setlocal
set "HERE=%~dp0"
set "PS1=%HERE%EMDASH-LOCK-v1.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS1%" (
  echo PowerShell file not found: "%PS1%"
  pause
  exit /b 1
)
"%PS%" -ExecutionPolicy Bypass -File "%PS1%"
