# fix-and-patch-ONECLICK-FLASHGUARD-v6.ps1
# Purpose: Inject a minimal, export-safe "flash guard" into every HTML file.
# It adds a temporary .nm-preload class to <html>, hides header/menu during first paint,
# then removes the class on DOM ready. No theme JS hooks required.
# PowerShell 5-compatible. No external modules. No backups by default.

param(
    [switch]$MakeBackup = $false
)

$ErrorActionPreference = 'Stop'

# Marker block to prevent duplicate injection
$markerStart = '<!-- NM_FLASHGUARD_START -->'
$markerEnd   = '<!-- NM_FLASHGUARD_END -->'

$css = @'
<style id="nm-flashguard-css">
/* NM FlashGuard — keep header from flashing raw logos/menus on static export */
html.nm-preload .ct-header,
html.nm-preload header.site-header { opacity: 0; }

/* Avoid bullet flash while hidden */
html.nm-preload .ct-header .menu,
html.nm-preload .ct-header .menu * { list-style: none !important; }

/* Hide alternate logo variants during preload */
html.nm-preload .header-logo img:not(:first-child) { display: none !important; }
</style>
'@

$js = @'
<script id="nm-flashguard-js">
/* NM FlashGuard — add/remove .nm-preload without relying on theme JS */
(function () {
  try {
    var docEl = document.documentElement;
    // Add preload class ASAP (script is in <head>)
    if (!docEl.classList.contains('nm-preload')) {
      docEl.classList.add('nm-preload');
    }
    var done = function () {
      try { docEl.classList.remove('nm-preload'); } catch (e) {}
    };
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', done, { once: true });
    } else {
      // DOM already parsed
      done();
    }
  } catch (e) { /* no-op */ }
})();
</script>
'@

$injection = "`n$markerStart`n$css`n$js`n$markerEnd`n"

# UTF-8 (no BOM) writer
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Collect HTML files (case-insensitive) recursively from the script folder
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File

if ($files.Count -eq 0) {
    Write-Host "No HTML files found under $root" -ForegroundColor Yellow
    exit 0
}

# Optional backup folder
$backupDir = Join-Path $root "_flashguard_bak"
if ($MakeBackup) {
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
}

$processed = 0
$skipped   = 0

foreach ($f in $files) {
    try {
        $content = Get-Content -Path $f.FullName -Raw -Encoding UTF8

        if ($content -like "*$markerStart*") {
            $skipped++
            continue
        }

        if ($MakeBackup) {
            $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
            $destPath = Join-Path $backupDir $rel
            $destDir = Split-Path -Parent $destPath
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
            Copy-Item -Path $f.FullName -Destination $destPath -Force
        }

        # Insert before closing </head>. If missing, prepend to file.
        $pattern = '</head>'
        $newContent = $null

        $idx = $content.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -ge 0) {
            $newContent = $content.Substring(0, $idx) + $injection + $content.Substring($idx)
        } else {
            $newContent = $injection + $content
        }

        [System.IO.File]::WriteAllText($f.FullName, $newContent, $utf8NoBom)
        $processed++
    } catch {
        Write-Warning ("Failed {0}: {1}" -f $f.FullName, $_.Exception.Message)
    }
}

Write-Host ("NM FlashGuard injected into {0} file(s), skipped (already patched): {1}" -f $processed, $skipped) -ForegroundColor Green
Write-Host "Done."
