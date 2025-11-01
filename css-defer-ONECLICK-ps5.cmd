@echo off
:: css-defer-ONECLICK-ps5.cmd (ASCII-only)
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0css-defer-ONECLICK-ps5.ps1" -Root "."
echo.
pause
