@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-and-patch-ONECLICK-FLASHGUARD-v6c.ps1"
echo.
echo Press any key to exit...
pause >nul
endlocal
