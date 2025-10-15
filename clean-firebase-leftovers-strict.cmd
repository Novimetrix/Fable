
@echo off
setlocal ENABLEDELAYEDEXPANSION
title Clean Firebase Leftovers (Strict) — flags only BAD references

REM Run from the ROOT of your exported site (folder that contains index.html)

echo === Strict scan for BAD firebase references (relative /www.gstatic.com only) ===

REM 1) Report bad src that start with /www.gstatic.com (rewritten) — these are the ones that break
powershell -NoProfile -Command ^
  "$hits = Select-String -Path (Get-ChildItem -Recurse -File -Include *.html,*.htm).FullName -Pattern 'src\s*=\s*[""'']\/www\.gstatic\.com\/firebasejs\/' -ErrorAction SilentlyContinue; "^
  "$c=$hits.Count; if(-not $c){$c=0}; Write-Host 'BAD src matches (must be 0):' $c; "^
  "if($c -gt 0){$hits | Select-Object -First 30 | ForEach-Object { $_.Path + ':' + $_.LineNumber + ' -> ' + $_.Line.Trim() }}"

echo.
echo === Optional cleanup of leftover firebase-*.html stubs ===
powershell -NoProfile -Command "Get-ChildItem -Recurse -File -Filter 'firebase-*.html' | Remove-Item -Force -ErrorAction SilentlyContinue"

echo.
echo === Tip ===
echo If BAD matches ^> 0, those files still contain a broken tag like src="/www.gstatic.com/firebasejs/...".
echo Remove that tag (or re-export with MU plugin 1.2.1 active) and rebuild.
echo.
pause
