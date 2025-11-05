# fix-and-patch-ONECLICK-FLASHGUARD-v7.ps1
# Always-on minimal CSS to eliminate header/menu flicker without any timing or JS.
# - Permanently removes nav bullets in header
# - Shows only the first logo image (prevents double logo) — safe if no sticky/alt logos
# - Hides "Skip to content" link visually (keeps it for screen readers via offscreen position)
# If you rely on sticky/alt logos, do not use v7.
param([switch]$MakeBackup = $false)

$ErrorActionPreference = 'Stop'

$markerStart = '<!-- NM_FLASHGUARD_START -->'
$markerEnd   = '<!-- NM_FLASHGUARD_END -->'

$css = @'
<style id="nm-flashguard-css">
/* NM FlashGuard v7 — always-on minimal guard (no JS) */
.ct-header .menu, .ct-header .menu * { list-style: none !important; padding-left: 0 !important; }
.header-logo img + img { display: none !important; } /* keep only first logo image visible */
a.skip-link { position: absolute !important; left: -9999px !important; } /* keep accessible but offscreen */
</style>
'@

$injection = "`n$markerStart`n$css`n$markerEnd`n"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File

if ($files.Count -eq 0) { Write-Host "No HTML files found under $root" -ForegroundColor Yellow; exit 0 }

$backupDir = Join-Path $root "_flashguard_bak"
if ($MakeBackup) { if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null } }

$processed = 0
$replaced  = 0

foreach ($f in $files) {
  try {
    $content = Get-Content -Path $f.FullName -Raw -Encoding UTF8

    if ($MakeBackup) {
      $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
      $destPath = Join-Path $backupDir $rel
      $destDir = Split-Path -Parent $destPath
      if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
      Copy-Item -Path $f.FullName -Destination $destPath -Force
    }

    $startIdx = $content.IndexOf($markerStart)
    if ($startIdx -ge 0) {
      $endIdx = $content.IndexOf($markerEnd, $startIdx)
      if ($endIdx -ge 0) {
        $afterEnd = $endIdx + $markerEnd.Length
        $newContent = $content.Substring(0, $startIdx) + $injection + $content.Substring($afterEnd)
      } else {
        $newContent = $injection + $content
      }
      [System.IO.File]::WriteAllText($f.FullName, $newContent, $utf8NoBom)
      $replaced++
      continue
    }

    $idxHead = $content.IndexOf('</head>', [System.StringComparison]::OrdinalIgnoreCase)
    if ($idxHead -ge 0) { $newContent = $content.Substring(0, $idxHead) + $injection + $content.Substring($idxHead) }
    else { $newContent = $injection + $content }
    [System.IO.File]::WriteAllText($f.FullName, $newContent, $utf8NoBom)
    $processed++
  } catch {
    Write-Warning ("Failed {0}: {1}" -f $f.FullName, $_.Exception.Message)
  }
}

Write-Host ("NM FlashGuard v7 (always-on) fresh: {0}, replaced: {1}" -f $processed, $replaced) -ForegroundColor Green
Write-Host "Done."
