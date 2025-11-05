@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0inject-no-bullets-v9c.ps1"
echo.
echo Press any key to exit...
pause >nul
endlocal
