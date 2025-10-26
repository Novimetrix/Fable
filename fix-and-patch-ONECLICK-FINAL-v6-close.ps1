# === ONECLICK FINAL v5 (PowerShell 5 SAFE) ===
# - Keeps lazy attrs (loading/decoding)
# - Cleans localhost refs
# - Normalizes data-* to real src/srcset
# - Adds src when only srcset exists (uses smallest candidate if descriptors present, else first)
# - Normalizes relative src ("wp-content/...") to "/wp-content/..."
# - Removes invalid sizes="auto, ..." token
param()

Write-Host "Running ONECLICK FINAL v5 (PS5-safe)..."

$files = Get-ChildItem -Recurse -File -Include *.html

foreach ($f in $files) {
  $path = $f.FullName
  $orig = Get-Content $path -Raw
  $html = $orig

  # 0) Scrub localhost/127.0.0.1 (plain & URL-encoded)
  $html = $html -replace 'https?://localhost(?::\d+)?', ''
  $html = $html -replace 'https?://127\.0\.0\.1(?::\d+)?', ''
  $html = $html -replace 'http%3A%2F%2Flocalhost(?::\d+)?', ''
  $html = $html -replace 'http%3A%2F%2F127%2E0%2E0%2E1(?::\d+)?', ''

  # 1) data-* → real attrs
  $pat_src = @'
<img([^>]*?)\s(?:data-lazy-src|data-src|data-original|data-echo)=["']([^"']+)["']([^>]*)>
'@
  $rep_src = @'
<img$1 src="$2"$3>
'@
  $html = $html -replace $pat_src, $rep_src

  $pat_srcset = @'
<(img|source)([^>]*?)\s(?:data-srcset|data-lazy-srcset)=["']([^"']+)["']([^>]*)>
'@
  $rep_srcset = @'
<$1$2 srcset="$3"$4>
'@
  $html = $html -replace $pat_srcset, $rep_srcset

  # 2) Add src if only srcset exists
  $pat_missing_src = @'
<img((?:(?!\ssrc=).)*?)\ssrcset=["']([^"']+)["']([^>]*)>
'@
  $html = [regex]::Replace($html, $pat_missing_src, {
    param($m)
    $set = $m.Groups[2].Value
    $bestUrl = $null
    $bestVal = [double]::PositiveInfinity
    foreach ($part in ($set -split ',')) {
      $p = $part.Trim()
      if (-not $p) { continue }
      $pieces = $p -split '\s+'
      $url = $pieces[0]
      if ($pieces.Count -ge 2) {
        $desc = $pieces[1]
        if ($desc -match '^(\d+(?:\.\d+)?)w$') { $val = [double]$matches[1] }
        elseif ($desc -match '^(\d+(?:\.\d+)?)x$') { $val = [double]$matches[1] * 1000 }
        else { $val = 1e9 }
      } else { $val = 1e9 }
      if ($val -lt $bestVal) { $bestVal = $val; $bestUrl = $url }
    }
    if (-not $bestUrl) { $bestUrl = (($set -split ',')[0].Trim().Split(' '))[0] }
    ("<img{0} src=""{1}"" srcset=""{2}""{3}>" -f $m.Groups[1].Value, $bestUrl, $set, $m.Groups[3].Value)
  })

  # 3) Normalize relative src ("wp-content/...") to "/..."
  $pat_rel_src = @'
<img([^>]*?)\ssrc=["'](?!https?:|/|data:|#)([^"']+)["']([^>]*?)>
'@
  $html = [regex]::Replace($html, $pat_rel_src, {
    param($m)
    $before = $m.Groups[1].Value
    $url    = $m.Groups[2].Value -replace '^(?:\./|\.\./)+',''
    $after  = $m.Groups[3].Value
    $prefix = '/'
    if ($url.StartsWith('/')) { $prefix = '' }
    ("<img{0} src=""{1}{2}""{3}>" -f $before, $prefix, $url, $after)
  })

  # 4) Remove invalid sizes="auto, ..." token
  $html = $html -replace '\ssizes=["'']\s*auto,\s*', ' sizes="'

  if ($html -ne $orig) {
    Set-Content $path $html -Encoding UTF8
    Write-Host ("Changed: {0}" -f $path)
  }
}

# Summary
$left_lazy = ($files | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern 'data-src|data-lazy-src|data-original|data-echo' -AllMatches | Measure-Object).Count
$missing_src = ($files | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern '<img(?![^>]*\ssrc=)[^>]*>' -AllMatches | Measure-Object).Count

Write-Host ""
Write-Host "ONECLICK FINAL v5 Summary:"
Write-Host ("  remaining lazy attrs: {0}" -f $left_lazy)
Write-Host ("  <img> without src:   {0}" -f $missing_src)
Write-Host ""
Write-Host "Done. Review, Commit, and Push."

# ===================== UTF‑8 HTML‑only sanitizer (integrated) =====================
function Invoke-Utf8SanitizerHtmlOnly {
  param([string]$Root)

  if (-not (Test-Path $Root)) { Write-Host "UTF-8 sanitizer: folder not found: $Root" -ForegroundColor Red; return }

  $cp1252 = [System.Text.Encoding]::GetEncoding(1252)
  $utf8   = [System.Text.Encoding]::UTF8

  Write-Host "UTF-8 sanitizer: scanning (HTML only) $Root" -ForegroundColor Cyan
  # Enumerate all, then filter extensions (works reliably with -Recurse)
  $files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in @('.html','.htm') } | Sort-Object FullName
  $tot = $files.Count
  Write-Host ("UTF-8 sanitizer: found {0} HTML files" -f $tot)

  $changed = 0; $injected = 0; $i = 0
  foreach($f in $files){
    $i++; Write-Host ("  [{0}/{1}] {2}" -f $i, $tot, $f.FullName)
    try {
      $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
      # Fast re-encode fix (cp1252 -> UTF8)
      $fixed = $utf8.GetString($cp1252.GetBytes($txt))

      # Optionally inject meta charset if missing
      $didInject = $false
      if ($fixed.IndexOf('<meta charset="utf-8"', [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        $headIdx = $fixed.IndexOf('<head', [StringComparison]::OrdinalIgnoreCase)
        if ($headIdx -ge 0) {
          $gt = $fixed.IndexOf('>', $headIdx)
          if ($gt -ge 0) {
            $fixed = $fixed.Insert($gt+1, "`r`n<meta charset=""utf-8"">")
            $didInject = $true
          }
        }
      }

      if ($fixed -ne $txt -or $didInject) {
        Set-Content -LiteralPath $f.FullName -Value $fixed -Encoding UTF8
        if($didInject){ $injected++ }
        $changed++
      }
    } catch {
      Write-Host ("  Error: {0} -> {1}" -f $f.FullName, $_) -ForegroundColor Red
    }
  }

  Write-Host ("UTF-8 sanitizer: done. files changed: {0}, meta injected: {1}" -f $changed, $injected) -ForegroundColor Green
}
# =============================================================================

# ---- Run UTF‑8 sanitizer on the repo export (folder where this script lives) ----
try {
  $scriptFolder = Split-Path -Parent $PSCommandPath
} catch {
  $scriptFolder = (Get-Location).Path
}
Invoke-Utf8SanitizerHtmlOnly -Root $scriptFolder
# -------------------------------------------------------------------------------

Write-Host ''
Read-Host 'Press Enter to close'
exit
