# inject-no-bullets-v9c.ps1
# Minimal fix: inject a tiny <style> that removes bullets for any lists inside the header/nav.
# No JS. Works even if UL lacks the "menu" class.
param([switch]$MakeBackup = $false)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File

if ($files.Count -eq 0) { Write-Host "No HTML files found under $root" -ForegroundColor Yellow; exit 0 }

$marker = '<!-- NM_NO_BULLETS_HEAD -->'
$styleBlock = @'
<!-- NM_NO_BULLETS_HEAD -->
<style>
/* NM No-Bullets v9c: kill list bullets in header nav at first paint */
header nav ul, header nav li,
.ct-header nav ul, .ct-header nav li,
header .menu, header .menu * {
  list-style: none !important;
  margin: 0 !important;
  padding-left: 0 !important;
}
</style>
'@

$added = 0
foreach ($f in $files) {
  try {
    $html = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
    if ($html.IndexOf($marker) -ge 0) { continue }
    $idxHead = $html.IndexOf('</head>', [System.StringComparison]::OrdinalIgnoreCase)
    $new = $null
    if ($idxHead -ge 0) {
      $new = $html.Substring(0, $idxHead) + "`n" + $styleBlock + "`n" + $html.Substring($idxHead)
    } else {
      $new = $styleBlock + $html
    }
    [System.IO.File]::WriteAllText($f.FullName, $new, $utf8NoBom)
    $added++
  } catch {
    Write-Warning ("Failed {0}: {1}" -f $f.FullName, $_.Exception.Message)
  }
}
Write-Host ("NM No-Bullets v9c injected into {0} file(s)." -f $added) -ForegroundColor Green
Write-Host "Done."
