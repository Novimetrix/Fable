@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0nm-final-flashfix-v10.ps1"
echo.
echo Press any key to exit...
pause >nul
endlocal
