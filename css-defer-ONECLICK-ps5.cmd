@echo off
:: css-defer-ONECLICK-ps5.cmd (QUIET, single prompt)
setlocal
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0css-defer-ONECLICK-ps5.ps1" -Root "."
echo.
echo Press any key to exit . . .
pause >nul
