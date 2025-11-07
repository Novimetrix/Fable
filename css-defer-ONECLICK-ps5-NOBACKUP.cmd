@echo off
REM css-defer-ONECLICK-ps5-NOBACKUP.cmd (FORCE-UNBLOCK)
setlocal
set SCRIPT=%~dp0css-defer-ONECLICK-ps5-NOBACKUP.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
endlocal
