@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0strip-logo-and-fix-menu-v9.ps1"
echo.
echo Press any key to exit...
pause >nul
endlocal
