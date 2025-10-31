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
  $orig = Get-Content -LiteralPath $path -Raw -Encoding UTF8
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
    Set-Content $path $html  -Encoding UTF8
    Write-Host ("Changed: {0}" -f $path)
  }
}

# Summary
$left_lazy = ($files | % { (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) } | Select-String -Pattern 'data-src|data-lazy-src|data-original|data-echo' -AllMatches | Measure-Object).Count
$missing_src = ($files | % { (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) } | Select-String -Pattern '<img(?![^>]*\ssrc=)[^>]*>' -AllMatches | Measure-Object).Count

Write-Host ""
Write-Host "ONECLICK FINAL v5 Summary:"
Write-Host ("  remaining lazy attrs: {0}" -f $left_lazy)
Write-Host ("  <img> without src:   {0}" -f $missing_src)
Write-Host ""
Write-Host "Done. Review, Commit, and Push."