# css-defer-ONECLICK-ps5-NOBACKUP-fixed.ps1
# Purpose: Defer non-critical stylesheets while KEEPING critical theme CSS blocking to avoid menu/logo flash.
# - PowerShell 5 safe; ASCII-friendly.
# - No backups created.
# How it works:
#   * Leaves any <link rel="stylesheet"> untouched if its href matches the skip list:
#       - /wp-content/themes/
#       - /themes/
#       - blocksy
#       - style.css
#       - wp-block-library
#   * Leaves links already marked media="print" or data-nm-deferred
#   * Converts remaining <link rel="stylesheet"> into a preload+print-onload pattern.
#
param([string]$Root = ".")
$ErrorActionPreference = "Stop"

$extensions = @("*.html","*.htm")
$re = [regex]'(?is)<link\s+([^>]*\brel\s*=\s*["'']stylesheet["''][^>]*)>'

# Substrings of href to SKIP deferring (keep as render-blocking)
$SkipHrefs = @(
  "/wp-content/themes/",
  "/themes/",
  "blocksy",
  "style.css",
  "wp-block-library"
)

function ShouldSkipHref {
  param([string]$attrs)
  $m = [regex]::Match($attrs,'(?is)\bhref\s*=\s*["'']([^"'']+)["'']')
  if(-not $m.Success){ return $true } # no href → skip
  $href = $m.Groups[1].Value
  foreach($needle in $SkipHrefs){
    if($href -like ("*{0}*" -f $needle)){ return $true }
  }
  return $false
}

function MakeTrio {
  param([string]$attrs)

  $m = [regex]::Match($attrs,'(?is)\bhref\s*=\s*["'']([^"'']+)["'']')
  if(-not $m.Success){ return $null }
  $href = $m.Groups[1].Value

  $integrity = ([regex]::Match($attrs,'(?is)\bintegrity\s*=\s*["'']([^"'']+)["'']')).Groups[1].Value
  $cross     = ([regex]::Match($attrs,'(?is)\bcrossorigin\s*=\s*["'']([^"'']+)["'']')).Groups[1].Value
  $refpol    = ([regex]::Match($attrs,'(?is)\breferrerpolicy\s*=\s*["'']([^"'']+)["'']')).Groups[1].Value

  $ia = ""; if($integrity){ $ia = " integrity=""$integrity""" }
  $ca = ""; if($cross){ $ca = " crossorigin=""$cross""" }
  $ra = ""; if($refpol){ $ra = " referrerpolicy=""$refpol""" }

  $preload = "<link rel=""preload"" as=""style"" href=""$href""$ia$ca$ra>"
  $lazy    = "<link rel=""stylesheet"" href=""$href"" media=""print"" onload=""this.media='all'"">$ia$ca$ra"

  return "$preload$lazy"
}

$changed = 0
$converted = 0

$files = Get-ChildItem -Path $Root -Recurse -Include $extensions -File
foreach($f in $files){
  $html = Get-Content -LiteralPath $f.FullName -Raw
  $new = $re.Replace($html, {
    param($m)
    $attrs = $m.Groups[1].Value

    # Respect existing flags
    if ($attrs -match '(?is)\bdata-nm-deferred\b' -or $attrs -match '(?is)\bmedia\s*=\s*["'']print["'']') {
      return $m.Value
    }

    # Keep critical CSS blocking
    if (ShouldSkipHref $attrs) {
      return $m.Value
    }

    $t = MakeTrio $attrs
    if($null -eq $t){ return $m.Value }
    $script:converted++
    return $t
  })

  if($new -ne $html){
    Set-Content -LiteralPath $f.FullName -Value $new -Encoding UTF8
    $changed++
  }
}

Write-Host ">>> Done. Files changed: $changed; Stylesheets converted: $converted"
