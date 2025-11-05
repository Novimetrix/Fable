@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0strip-logo-fix-menu-v9b.ps1"
echo.
echo Press any key to exit...
pause >nul
endlocal
