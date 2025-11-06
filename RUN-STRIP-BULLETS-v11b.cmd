@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0strip-bullets-nav-or-menu-v11b.ps1"
echo.
echo Press any key to exit...
pause >nul
endlocal
