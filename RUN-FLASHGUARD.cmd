@echo off
setlocal
REM Run the FlashGuard patch from the folder it's placed in
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-and-patch-ONECLICK-FLASHGUARD-v6.ps1"
echo.
echo Press any key to exit...
pause >nul
endlocal
