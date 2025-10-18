@echo off
:: Runs ONECLICK FINAL script beside this file.
powershell -ExecutionPolicy Bypass -File "%~dp0fix-and-patch-ONECLICK-FINAL.ps1"
echo.
pause
