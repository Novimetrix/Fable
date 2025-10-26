# EMDASH-LOCK-v1.ps1 — Fix inconsistent em‑dash width across devices
$ErrorActionPreference = 'Stop'

# Work in the folder where this script lives
$Root = Split-Path -Parent $PSCommandPath
if (-not (Test-Path $Root)) { Write-Host "Folder not found: $Root" -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }

Write-Host "Scanning: $Root" -ForegroundColor Cyan
$files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in @('.html','.htm') } | Sort-Object FullName
$tot = $files.Count
Write-Host ("Found {0} HTML files" -f $tot)

# CSS block to normalize em‑dash rendering
$css = 'body{font-variant-ligatures:none;font-feature-settings:"liga" 0,"lnum" 0,"kern" 0;font-family:system-ui,"Segoe UI",sans-serif;}'
$styleTag = '<style id="emdash-lock">'+$css+'</style>'

$changed = 0; $skipped = 0; $i = 0
foreach ($f in $files) {
  $i++
  $path = $f.FullName
  Write-Host ("[{0}/{1}] {2}" -f $i, $tot, $path)
  try {
    $txt = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($txt -match 'id=["'']emdash-lock["'']') { $skipped++; continue }

    $headIdx = $txt.IndexOf('<head', [StringComparison]::OrdinalIgnoreCase)
    if ($headIdx -ge 0) {
      $gt = $txt.IndexOf('>', $headIdx)
      if ($gt -ge 0) {
        $txt = $txt.Insert($gt+1, "`r`n"+$styleTag+"`r`n")
      } else {
        $txt = $styleTag + "`r`n" + $txt
      }
    } else {
      $txt = $styleTag + "`r`n" + $txt
    }
    Set-Content -LiteralPath $path -Value $txt -Encoding UTF8
    $changed++
  } catch {
    Write-Host ("  Error: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host ("Done. Files changed: {0}, skipped: {1}" -f $changed, $skipped) -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to close"
exit
