# css-defer-ONECLICK-ps5-NOBACKUP.ps1
# Plain ASCII, PowerShell 5-safe. No prompts, no backups.
# Behavior:
# - Defer NON-CRITICAL stylesheets by switching to media="print" and flipping to media="all" via onload.
# - Preserve integrity/crossorigin/referrerpolicy attributes (we don't touch them).
# - Add <noscript> fallback for each deferred stylesheet.
# - Skip critical CSS via the skip list below.
# - UTF-8 (no BOM) writes.
# Exit codes: 0 success, 2 regex failure, 3 write failure.

$ErrorActionPreference = 'Stop'

# === SKIP LIST (never defer if tag or href contains any of these) ===
$SkipList = @(
  'blocksy',
  'ct-main',
  'wp-block-library',
  'global-styles',
  '/wp-content/themes/',
  'style.css',
  '/wp-includes/css/',
  'stackable-ultimate-gutenberg-blocks'  # NEW: keep Stackable CSS render-blocking
)

# Regex to find link rel="stylesheet" tags (single line or multi-line)
$Pattern = '<link\b(?:(?!>)[\s\S])*?\brel=["'']stylesheet["''](?:(?!>)[\s\S])*?>'

function Should-SkipLink([string]$tag, [string]$href) {
  foreach ($s in $SkipList) {
    if ($tag -like ("*" + $s + "*")) { return $true }
    if ($href -and $href -like ("*" + $s + "*")) { return $true }
  }
  return $false
}

function Convert-Link([string]$tag) {
  # If already deferred with this pattern, leave as-is
  if ($tag -match 'media\s*=\s*["'']print["'']' -and $tag -match 'onload\s*=\s*["''][^"'']*this\.media\s*=\s*[\'']all[\'']') { return $tag }
  if ($tag -match 'data-deferred\s*=\s*["'']1["'']') { return $tag }

  # Extract href
  $href = $null
  $m = [regex]::Match($tag, 'href\s*=\s*["'']([^"'']+)["'']', 'IgnoreCase')
  if ($m.Success) { $href = $m.Groups[1].Value }

  # Skip critical files
  if (Should-SkipLink $tag $href) { return $tag }

  # Ensure media="print"
  if ($tag -match '\bmedia\s*=\s*["''][^"'']*["'']') {
    $tag = [regex]::Replace($tag, '\bmedia\s*=\s*["''][^"'']*["'']', 'media="print"', 'IgnoreCase')
  } else {
    $tag = $tag -replace '>$', ' media="print">'
  }

  # Add/append onload to flip to 'all'
  if ($tag -notmatch '\bonload\s*=') {
    $tag = $tag -replace '>$', ' onload="this.media=''all''">'
  } elseif ($tag -notmatch 'this\.media\s*=\s*[\'']all[\'']') {
    $tag = [regex]::Replace($tag, '\bonload\s*=\s*["'']([^"'']*)["'']', {
      param($m2)
      $code = $m2.Groups[1].Value
      $new = $code.TrimEnd(';') + ';this.media=''all'''
      'onload="' + $new + '"'
    }, 'IgnoreCase')
  }

  # Mark as deferred (for visibility/tools)
  if ($tag -notmatch 'data-deferred\s*=') {
    $tag = $tag -replace '>$', ' data-deferred="1">'
  }

  # Build noscript fallback
  $noscript = ''
  if ($href) {
    $escaped = $href -replace '"', '&quot;'
    $noscript = "<noscript data-deferred-fallback=""1""><link rel=""stylesheet"" href=""$escaped""></noscript>"
  }

  return $tag + $noscript
}

# Process *.html / *.htm recursively from current directory
$files = Get-ChildItem -Recurse -Include *.html, *.htm -File
[int]$changed = 0

foreach ($f in $files) {
  try {
    $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  } catch {
    $content = Get-Content -LiteralPath $f.FullName -Raw
  }

  $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
    param($m3)
    $orig = $m3.Value
    return (Convert-Link $orig)
  }

  try {
    $updated = [regex]::Replace($content, $Pattern, $evaluator, 'IgnoreCase')
  } catch {
    Write-Error ("Regex failure in file: " + $f.FullName + " :: " + $_.Exception.Message)
    exit 2
  }

  if ($updated -ne $content) {
    try {
      $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
      [System.IO.File]::WriteAllText($f.FullName, $updated, $utf8NoBom)
      $changed++
    } catch {
      Write-Error ("Write failure in file: " + $f.FullName + " :: " + $_.Exception.Message)
      exit 3
    }
  }
}

Write-Host ("Deferred CSS in " + $changed + " file(s). Skipped critical CSS. Added noscript fallbacks.")
exit 0
