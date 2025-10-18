@echo off
:: === fix-and-patch-ONECLICK.cmd (auto-detects .ps1 in same folder) ===
:: Runs the PowerShell patch script located beside this file.
powershell -ExecutionPolicy Bypass -File "%~dp0fix-and-patch-ONECLICK-UPDATED.ps1"
echo.
pause
