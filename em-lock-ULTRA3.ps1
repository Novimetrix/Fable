# em-lock-ULTRA3.ps1 — Lock 1em on mobile to desktop size (no args; works in-place)
$ErrorActionPreference = 'Stop'

# Target folder = where this script lives
$Root = Split-Path -Parent $PSCommandPath
if (-not (Test-Path $Root)) { Write-Host "Folder not found: $Root" -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }

Write-Host "Scanning (HTML only): $Root" -ForegroundColor Cyan

# Enumerate files safely and filter by extension (avoids -Include/-Recurse quirks)
$files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in @('.html','.htm') } | Sort-Object FullName
$tot = $files.Count
Write-Host ("Found {0} HTML files" -f $tot)

# One-line CSS to avoid quoting issues
$cssOneLine = 'html{-webkit-text-size-adjust:100%!important;text-size-adjust:100%!important}@media (max-width:1024px){html{font-size:16px!important}}'
$styleTag   = '<style id="em-mobile-size-lock">'+$cssOneLine+'</style>'

$changed = 0; $i = 0
foreach($f in $files){
  $i++
  Write-Host ("[{0}/{1}] {2}" -f $i, $tot, $f.FullName)
  try {
    $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8

    # Skip if already injected
    if ($txt.IndexOf('em-mobile-size-lock', [StringComparison]::OrdinalIgnoreCase) -ge 0) { continue }

    # Insert after <head ...>
    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    $headIdx = $ci.CompareInfo.IndexOf($txt, '<head', [System.Globalization.CompareOptions]::IgnoreCase)
    if ($headIdx -ge 0) {
      $gt = $txt.IndexOf('>', $headIdx)
      if ($gt -ge 0) {
        $newTxt = $txt.Insert($gt+1, "`r`n"+$styleTag+"`r`n")
      } else {
        $newTxt = $styleTag + "`r`n" + $txt
      }
    } else {
      $newTxt = $styleTag + "`r`n" + $txt
    }

    if ($newTxt -ne $txt) {
      Set-Content -LiteralPath $f.FullName -Value $newTxt -Encoding UTF8
      $changed++
    }
  } catch {
    Write-Host ("  Error: {0} -> {1}" -f $f.FullName, $_) -ForegroundColor Red
  }
}

Write-Host ("Done. Files changed: {0}" -f $changed) -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to close"
exit
