
@echo off
setlocal ENABLEDELAYEDEXPANSION
title Clean Firebase Leftovers (HTTrack export)

REM Run from the ROOT of your exported site (folder that contains index.html)
REM This removes bogus firebase-*.html files and any www.gstatic.com folders,
REM then shows a quick report of remaining bad references.

echo === Cleaning Firebase leftovers ===

REM Count & delete firebase-*.html
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-ChildItem -Recurse -File -Filter 'firebase-*.html').Count"') do set COUNT_HTML=%%A
if "%COUNT_HTML%"=="" set COUNT_HTML=0
echo Found %COUNT_HTML% file^(s^) like firebase-*.html
powershell -NoProfile -Command "Get-ChildItem -Recurse -File -Filter 'firebase-*.html' | Remove-Item -Force -ErrorAction SilentlyContinue"

REM Remove any accidentally created www.gstatic.com folders
powershell -NoProfile -Command "$d=Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue | ? Name -eq 'www.gstatic.com'; $n=$d.Count; if(-not $n){$n=0}; Write-Host 'Found' $n 'www.gstatic.com folder(s)'; if($n -gt 0){$d | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue}"

echo.
echo === Scan for bad firebase references in HTML (should be 0) ===
powershell -NoProfile -Command "$hits = Select-String -Path (Get-ChildItem -Recurse -File -Include *.html,*.htm).FullName -Pattern '/www\.gstatic\.com/firebasejs/' -ErrorAction SilentlyContinue; $c=$hits.Count; if(-not $c){$c=0}; Write-Host 'Matches:' $c; if($c -gt 0){$hits | Select-Object -First 20 | ForEach-Object { $_.Path + ':' + $_.LineNumber + ' -> ' + $_.Line.Trim() }}"

echo.
echo === Done ===
echo If "Matches: 0" above, you're clean. Commit/push your export as usual.
echo.
pause
