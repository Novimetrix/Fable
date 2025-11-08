# css-preload-critical-ONECLICK-ps5-NOBACKUP.ps1
# Fast, simplified: PRELOAD critical CSS + add Google Fonts preconnects.
# No image heuristics (avoids regex timeouts). No prompts/backups. PS5-safe. Plain ASCII.

$ErrorActionPreference = 'Stop'

# Critical CSS identifiers (substring match)
$CriticalCss = @(
  '/wp-includes/css/dist/block-library/',
  '/wp-content/themes/blocksy/',
  'ct-main',
  '/wp-content/plugins/stackable-ultimate-gutenberg-blocks/',
  'global-styles',
  'wp-block-library'
)

# Fonts preconnects
$FontsHosts = @(
  'https://fonts.googleapis.com',
  'https://fonts.gstatic.com'
)

# Regex
$LinkStylesheet = '<link\b(?:(?!>)[\s\S])*?\brel=["'']stylesheet["''](?:(?!>)[\s\S])*?>'
$HrefRx = 'href\s*=\s*["'']([^"'']+)["'']'
$HeadClose = '</head>'

function ContainsAny([string]$text, [array]$needles) {
  foreach ($n in $needles) {
    if ($text -like ("*" + $n + "*")) { return $true }
  }
  return $false
}

function Ensure-Preconnect([string]$html) {
  $inject = @()
  foreach ($h in $FontsHosts) {
    if ($html -notmatch [regex]::Escape($h)) {
      $inject += ('<link rel="preconnect" href="' + $h + '" crossorigin>')
    }
  }
  if ($inject.Count -gt 0 -and $html -match $HeadClose) {
    $blob = [string]::Join("`n", $inject) + "`n"
    return [regex]::Replace($html, $HeadClose, $blob + $HeadClose, 'IgnoreCase')
  }
  return $html
}

function Ensure-PreloadStyle([string]$html) {
  $matches = [regex]::Matches($html, $LinkStylesheet, 'IgnoreCase')
  if ($matches.Count -eq 0) { return $html }

  # Map existing style-preloads to avoid duplicates
  $existing = New-Object 'System.Collections.Generic.HashSet[string]'
  $preRx = '<link\b[^>]*\brel=["'']preload["''][^>]*\bas=["'']style["''][^>]*>'
  foreach ($m2 in [regex]::Matches($html, $preRx, 'IgnoreCase')) {
    $hm = [regex]::Match($m2.Value, $HrefRx, 'IgnoreCase')
    if ($hm.Success) { [void]$existing.Add($hm.Groups[1].Value) }
  }

  $sb = New-Object System.Text.StringBuilder
  $last = 0
  foreach ($m in $matches) {
    $tag = $m.Value
    $href = ''
    $hm = [regex]::Match($tag, $HrefRx, 'IgnoreCase')
    if ($hm.Success) { $href = $hm.Groups[1].Value }

    if ($href -ne '' -and (ContainsAny $tag $CriticalCss -or ContainsAny $href $CriticalCss)) {
      if (-not $existing.Contains($href)) {
        $pre = '<link rel="preload" as="style" href="' + $href + '">'
        $sb.Append($html.Substring($last, $m.Index - $last)) | Out-Null
        $sb.Append($pre) | Out-Null
        $sb.Append($tag) | Out-Null
        $last = $m.Index + $m.Length
        continue
      }
    }
    $sb.Append($html.Substring($last, $m.Index - $last)) | Out-Null
    $sb.Append($tag) | Out-Null
    $last = $m.Index + $m.Length
  }
  $sb.Append($html.Substring($last)) | Out-Null
  return $sb.ToString()
}

$files = Get-ChildItem -Recurse -Include *.html, *.htm -File
[int]$changed = 0

foreach ($f in $files) {
  try { $html = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 } catch { $html = Get-Content -LiteralPath $f.FullName -Raw }
  $orig = $html
  $html = Ensure-Preconnect $html
  $html = Ensure-PreloadStyle $html

  if ($html -ne $orig) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($f.FullName, $html, $utf8NoBom)
    $changed++
  }
}

Write-Host ("Preload (CSS+fonts) applied in " + $changed + " file(s).")
exit 0
