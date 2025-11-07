# fix-and-patch-ONECLICK-FLASHGUARD-v6b.ps1
# Stronger FlashGuard: reveal after DOM parsed + 2 rAF + 120ms, with 1200ms safety timeout.
# Replaces any previous NM_FLASHGUARD block if present.
param(
    [switch]$MakeBackup = $false
)

$ErrorActionPreference = 'Stop'

$markerStart = '<!-- NM_FLASHGUARD_START -->'
$markerEnd   = '<!-- NM_FLASHGUARD_END -->'

$css = @'
<style id="nm-flashguard-css">
/* NM FlashGuard v6b — smooth header reveal on static exports */
html.nm-preload .ct-header,
html.nm-preload header.site-header { opacity: 0; pointer-events: none; }

/* Avoid bullet flash while hidden */
html.nm-preload .ct-header .menu,
html.nm-preload .ct-header .menu * { list-style: none !important; }

/* Hide alternate logo variants during preload */
html.nm-preload .header-logo img:not(:first-child) { display: none !important; }
</style>
'@

$js = @'
<script id="nm-flashguard-js">
/* NM FlashGuard v6b — theme-agnostic guard */
(function () {
  try {
    var doc = document, docEl = doc.documentElement;
    if (!docEl.classList.contains('nm-preload')) docEl.classList.add('nm-preload');

    var revealed = false;
    function reveal() {
      if (revealed) return;
      revealed = true;
      try { docEl.classList.remove('nm-preload'); } catch(e){}
    }

    // Minimum-delay reveal once DOM is parsed: 2 rAF ticks + 120ms
    function domReadyReveal() {
      try {
        requestAnimationFrame(function(){
          requestAnimationFrame(function(){
            setTimeout(reveal, 120);
          });
        });
      } catch(e) {
        setTimeout(reveal, 180);
      }
    }

    if (doc.readyState === 'loading') {
      doc.addEventListener('DOMContentLoaded', domReadyReveal, { once: true });
    } else {
      domReadyReveal();
    }

    // Safety: never keep hidden longer than 1200ms
    setTimeout(reveal, 1200);

    // If window fully loads earlier, reveal then as well (covers heavy CSS fetches)
    window.addEventListener('load', reveal, { once: true });
  } catch (e) { /* no-op */ }
})();
</script>
'@

$injection = "`n$markerStart`n$css`n$js`n$markerEnd`n"

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

    $pattern = '</head>'
    $idx = $content.IndexOf($markerStart)
    if ($idx -ge 0) {
      # Replace existing block
      $startIdx = $idx
      $endIdx = $content.IndexOf($markerEnd, $startIdx)
      if ($endIdx -ge 0) {
        $afterEnd = $endIdx + $markerEnd.Length
        $newContent = $content.Substring(0, $startIdx) + $injection + $content.Substring($afterEnd)
      } else {
        # Marker start found but end missing — just insert a new block before </head>
        $idxHead = $content.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idxHead -ge 0) { $newContent = $content.Substring(0, $idxHead) + $injection + $content.Substring($idxHead) }
        else { $newContent = $injection + $content }
      }
      [System.IO.File]::WriteAllText($f.FullName, $newContent, $utf8NoBom)
      $replaced++
      continue
    }

    # Fresh inject
    $idxHead2 = $content.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase)
    if ($idxHead2 -ge 0) { $newContent = $content.Substring(0, $idxHead2) + $injection + $content.Substring($idxHead2) }
    else { $newContent = $injection + $content }
    [System.IO.File]::WriteAllText($f.FullName, $newContent, $utf8NoBom)
    $processed++
  } catch {
    Write-Warning ("Failed {0}: {1}" -f $f.FullName, $_.Exception.Message)
  }
}

Write-Host ("NM FlashGuard v6b fresh: {0}, replaced: {1}" -f $processed, $replaced) -ForegroundColor Green
Write-Host "Done."
