@echo off
setlocal
set "HERE=%~dp0"
set "PSX=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
"%PSX%" -ExecutionPolicy Bypass -File "%HERE%fix-and-patch-ONECLICK-FINAL-v6-close.ps1"
