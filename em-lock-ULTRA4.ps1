# em-lock-ULTRA4.ps1 — Stronger "same em on mobile" patch
$ErrorActionPreference = 'Stop'

# Work in the folder where this script lives
$Root = Split-Path -Parent $PSCommandPath
if (-not (Test-Path $Root)) { Write-Host "Folder not found: $Root" -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }

Write-Host "Scanning (HTML only): $Root" -ForegroundColor Cyan

# Gather HTML files safely
$files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in @('.html','.htm') } | Sort-Object FullName
$tot = $files.Count
Write-Host ("Found {0} HTML files" -f $tot)

# Stronger CSS (one-liner to avoid quoting issues)
$cssOneLine = 'html{-webkit-text-size-adjust:100%!important;text-size-adjust:100%!important}@media (max-width:1024px){html,body{font-size:16px!important;line-height:1.5} :root{--font-size-base:16px!important;--text-font-size:16px!important}}'
$styleStart = '<style id="em-mobile-size-lock">'
$styleTag   = $styleStart + $cssOneLine + '</style>'

function Ensure-Viewport($html){
  # If a viewport meta already exists, keep it. Otherwise add a standard one after <head>
  if ($html.IndexOf('<meta name="viewport"', [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $html }
  $headIdx = [System.Globalization.CultureInfo]::InvariantCulture.CompareInfo.IndexOf($html, '<head', [System.Globalization.CompareOptions]::IgnoreCase)
  if ($headIdx -ge 0) {
    $gt = $html.IndexOf('>', $headIdx)
    if ($gt -ge 0) {
      return $html.Insert($gt+1, "`r`n<meta name=""viewport"" content=""width=device-width, initial-scale=1"">`r`n")
    }
  }
  return "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">`r`n" + $html
}

$changed = 0; $i = 0; $replaced = 0; $inserted = 0; $vpAdded = 0
foreach($f in $files){
  $i++
  Write-Host ("[{0}/{1}] {2}" -f $i, $tot, $f.FullName)
  try {
    $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8

    # Ensure viewport
    $newTxt = Ensure-Viewport $txt
    if ($newTxt -ne $txt) { $txt = $newTxt; $vpAdded++ }

    # Replace existing style (if our id is already there), else insert after <head>
    $idx = $txt.IndexOf($styleStart, [StringComparison]::OrdinalIgnoreCase)
    if ($idx -ge 0) {
      # Find closing </style> after idx
      $endIdx = $txt.IndexOf('</style>', $idx)
      if ($endIdx -gt $idx) {
        $endIdx += 8  # include closing tag
        $txt = $txt.Substring(0,$idx) + $styleTag + $txt.Substring($endIdx)
        $replaced++
      } else {
        # malformed? just insert fresh at top
        $txt = $styleTag + "`r`n" + $txt
        $inserted++
      }
    } else {
      # insert after <head>
      $ci = [System.Globalization.CultureInfo]::InvariantCulture
      $headIdx = $ci.CompareInfo.IndexOf($txt, '<head', [System.Globalization.CompareOptions]::IgnoreCase)
      if ($headIdx -ge 0) {
        $gt = $txt.IndexOf('>', $headIdx)
        if ($gt -ge 0) {
          $txt = $txt.Insert($gt+1, "`r`n"+$styleTag+"`r`n")
          $inserted++
        } else {
          $txt = $styleTag + "`r`n" + $txt
          $inserted++
        }
      } else {
        $txt = $styleTag + "`r`n" + $txt
        $inserted++
      }
    }

    Set-Content -LiteralPath $f.FullName -Value $txt -Encoding UTF8
    $changed++
  } catch {
    Write-Host ("  Error: {0} -> {1}" -f $f.FullName, $_) -ForegroundColor Red
  }
}

Write-Host ("Done. Files changed: {0}. styles replaced: {1}, styles inserted: {2}, viewport added: {3}" -f $changed, $replaced, $inserted, $vpAdded) -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to close"
exit
