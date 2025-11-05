# fix-and-patch-ONECLICK-FLASHGUARD-v6c.ps1
# Lighter FlashGuard to minimize LCP impact:
# - Only suppresses duplicate logo variants and bullet styles during preload.
# - No full-header opacity mask.
# - Reveal at DOMContentLoaded + 40ms (no rAF). Safety: 800ms.
param([switch]$MakeBackup = $false)

$ErrorActionPreference = 'Stop'

$markerStart = '<!-- NM_FLASHGUARD_START -->'
$markerEnd   = '<!-- NM_FLASHGUARD_END -->'

$css = @'
<style id="nm-flashguard-css">
/* NM FlashGuard v6c — minimal impact */
html.nm-preload .ct-header .menu,
html.nm-preload .ct-header .menu * { list-style: none !important; }

/* Hide alternate logo variants during preload (avoid double logo) */
html.nm-preload .header-logo img:not(:first-child) { display: none !important; }

/* Keep Skip-to-content hidden during preload to avoid top-left flash */
html.nm-preload a.skip-link { position: absolute !important; left: -9999px !important; }
</style>
'@

$js = @'
<script id="nm-flashguard-js">
/* NM FlashGuard v6c — minimal delay to reduce LCP effects */
(function () {
  try {
    var d = document, html = d.documentElement, revealed = false;
    if (!html.classList.contains('nm-preload')) html.classList.add('nm-preload');
    function reveal(){ if (revealed) return; revealed = true; try{ html.classList.remove('nm-preload'); }catch(e){} }
    function domReady(){ setTimeout(reveal, 40); }  // small buffer only
    if (d.readyState === 'loading') { d.addEventListener('DOMContentLoaded', domReady, {once:true}); }
    else { domReady(); }
    setTimeout(reveal, 800);   // safety cap
    window.addEventListener('load', reveal, {once:true});
  } catch(e){}
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

Write-Host ("NM FlashGuard v6c fresh: {0}, replaced: {1}" -f $processed, $replaced) -ForegroundColor Green
Write-Host "Done."
