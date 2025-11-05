# fix-and-patch-ONECLICK-FLASHGUARD-v6d.ps1
# Goal: kill header flicker reliably while minimizing LCP impact.
# Strategy:
#  - During preload: show ONLY the first logo image, hide all others;
#    hide nav bullets and temporarily fade the nav block to avoid unstyled jump.
#  - Reveal on window 'load' (CSS/JS settled) OR after 1200ms as safety.
#  - Replace any previous NM_FLASHGUARD block automatically.
param([switch]$MakeBackup = $false)

$ErrorActionPreference = 'Stop'

$markerStart = '<!-- NM_FLASHGUARD_START -->'
$markerEnd   = '<!-- NM_FLASHGUARD_END -->'

$css = @'
<style id="nm-flashguard-css">
/* NM FlashGuard v6d — robust, minimal LCP impact */

/* Only permit a single logo during preload */
html.nm-preload .header-logo img { display: none !important; }
html.nm-preload .header-logo img:first-of-type { display: inline-block !important; }

/* Prevent bullet flash and raw list spacing */
html.nm-preload .ct-header .menu,
html.nm-preload .ct-header .menu * { list-style: none !important; padding-left: 0 !important; }

/* Soften unstyled nav text without hiding whole header */
html.nm-preload .ct-main-navigation,
html.nm-preload nav[role="navigation"] { opacity: 0; }

/* Hide "Skip to content" link during preload */
html.nm-preload a.skip-link { position: absolute !important; left: -9999px !important; }
</style>
'@

$js = @'
<script id="nm-flashguard-js">
/* NM FlashGuard v6d — reveal on window.load (preferred) or 1200ms safety */
(function () {
  try {
    var d = document, html = d.documentElement, revealed = false;
    if (!html.classList.contains('nm-preload')) html.classList.add('nm-preload');
    function reveal(){ if (revealed) return; revealed = true; try{ html.classList.remove('nm-preload'); }catch(e){} }
    // Prefer full load to ensure theme CSS/JS applied
    window.addEventListener('load', reveal, { once:true });
    // Safety cap
    setTimeout(reveal, 1200);
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

Write-Host ("NM FlashGuard v6d fresh: {0}, replaced: {1}" -f $processed, $replaced) -ForegroundColor Green
Write-Host "Done."
