# css-defer-ONECLICK-ps5.ps1  (ASCII-only, PowerShell 5 safe)
param([string]$Root = ".")
$ErrorActionPreference = "Stop"

$extensions = @("*.html","*.htm")
$re = [regex]'(?is)<link\s+([^>]*\brel\s*=\s*["'']stylesheet["''][^>]*)>'

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

  $pre = "<link rel=""preload"" as=""style"" href=""$href""$ia$ca$ra data-nm-deferred=""1"">"
  $def = "<link rel=""stylesheet"" href=""$href"" media=""print"" onload=""this.media='all'""$ia$ca$ra data-nm-deferred=""1"">"
  $nos = "<noscript><link rel=""stylesheet"" href=""$href""$ia$ca$ra></noscript>"
  return "$pre`r`n$def`r`n$nos"
}

$rootPath = Resolve-Path $Root
Write-Host ">>> ONECLICK CSS Defer -- $rootPath"

$files = Get-ChildItem -Path $rootPath -Recurse -Include $extensions -File | Sort-Object FullName
if(-not $files){
  Write-Host "No HTML files found."
  # Read-Host "Press Enter to exit"  <-- REMOVED for CI/automation
  exit 0
}

[int]$changed=0
[int]$converted=0

foreach($f in $files){
  $html = Get-Content -Raw -LiteralPath $f.FullName

  $new = $re.Replace($html,{
    param($m)
    $attrs = $m.Groups[1].Value

    # --- START FOUC FIX: EXCLUDE CRITICAL BLOCKS ---
    # EXCLUDE critical theme/block CSS from deferral (keep render-blocking)
    # This prevents FOUC and broken styling for the menu, Gutenberg blocks, and base theme styles.
    if ($attrs -match '(?is)blocksy|ct-main|wp-block-library|global-styles|/wp-content/themes/|style\.css') {
        Write-Host "Skipping critical theme/block CSS." -ForegroundColor Yellow
        return $m.Value 
    }
    # --- END FOUC FIX ---

    if ($attrs -match '(?is)\bdata-nm-deferred\b' -or $attrs -match '(?is)\bmedia\s*=\s*["'']print["'']') { return $m.Value }
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
# Read-Host "Press Enter to exit" <-- REMOVED for CI/automation