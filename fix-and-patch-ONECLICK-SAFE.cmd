@echo off
:: === fix-and-patch-ONECLICK-SAFE.cmd ===
:: Runs the SAFE PS1 located beside this file.
powershell -ExecutionPolicy Bypass -File "%~dp0fix-and-patch-ONECLICK-SAFE.ps1"
echo.
pause
