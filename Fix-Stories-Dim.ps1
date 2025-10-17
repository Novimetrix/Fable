<#
Fix-Stories-Dim.ps1
One-click post-export fixer for Fable Odyssey static site.

What it does (only for /stories*/ and /blog*/ HTML files):
  1) Removes "inert" attributes that keep pages unclickable/dim.
  2) Removes data-panel="..." on <body> if present.
  3) Strips stuck "open" classes (menu-open, drawer-open, etc.) from <html>/<body> class attributes.
  4) Deletes common overlay/backdrop nodes like .ct-drawer-backdrop.
  5) Injects a tiny CSS guard (opacity:1; filter:none) in <head> if not already present.

Usage:
  - Open PowerShell
  - Run:  .\Fix-Stories-Dim.ps1 -ExportRoot "C:\Path\to\your\export\root"
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$ExportRoot
)

# --- Helpers ---
function Fix-File {
  param([string]$Path)

  $content = Get-Content -Raw -LiteralPath $Path

  $orig = $content

  # 1) Remove inert attributes anywhere (space + inert[=...])
  $content = [Regex]::Replace($content, '\s+inert(\s*=\s*(?:"[^"]*"|\'[^\']*\'|[^\s>]*))?', '', 'IgnoreCase')

  # 2) Remove data-panel="..." on <body ...>
  $content = [Regex]::Replace($content, '<body([^>]*?)\sdata-panel="[^"]*"(.*?)>', '<body$1$2>', 'IgnoreCase')

  # 3) Strip "open" classes from html/body class attributes
  $kill = 'menu-open|drawer-open|offcanvas-open|mm-wrapper_opened|ct-panel--open|has-modal|no-scroll'
  # html class="..."
  $content = [Regex]::Replace($content, '<html([^>]*?)class="([^"]*?)"', {
      param($m)
      $pre = $m.Groups[1].Value
      $cls = $m.Groups[2].Value
      $new = [Regex]::Replace($cls, "(?:^|\s)($kill)(?=\s|$)", "", "IgnoreCase")
      $new = [Regex]::Replace($new, '\s{2,}', ' ').Trim()
      if ($new -ne '') { "<html$pre" + 'class="' + $new + '"' } else { "<html$pre" }
    }, 'IgnoreCase')
  # body class="..."
  $content = [Regex]::Replace($content, '<body([^>]*?)class="([^"]*?)"', {
      param($m)
      $pre = $m.Groups[1].Value
      $cls = $m.Groups[2].Value
      $new = [Regex]::Replace($cls, "(?:^|\s)($kill)(?=\s|$)", "", "IgnoreCase")
      $new = [Regex]::Replace($new, '\s{2,}', ' ').Trim()
      if ($new -ne '') { "<body$pre" + 'class="' + $new + '"' } else { "<body$pre" }
    }, 'IgnoreCase')

  # 4) Remove common overlay/backdrop nodes (simple tag-level removal)
  $overlayClasses = @(
    'ct-drawer-backdrop','drawer-backdrop','offcanvas-backdrop','site-overlay',
    'mm-ocd','mfp-bg','modal-backdrop'
  )
  foreach ($cl in $overlayClasses) {
    $pattern = '<(div|span)([^>]*?)class="[^"]*?\b' + [Regex]::Escape($cl) + '\b[^"]*?"[^>]*?>\s*</\1>'
    $content = [Regex]::Replace($content, $pattern, '', 'IgnoreCase')
  }

  # 5) Inject tiny CSS guard into <head> if not present
  if ($content -notmatch 'id="fo-de-dim"') {
    $guard = '<style id="fo-de-dim">html,body{opacity:1!important;filter:none!important}</style>'
    if ($content -match '</head>') {
      $content = [Regex]::Replace($content, '</head>', ($guard + '</head>'), 1, 'IgnoreCase')
    }
  }

  if ($content -ne $orig) {
    Set-Content -LiteralPath $Path -Value $content -Encoding UTF8
    return $true
  }

  return $false
}

# --- Target files: only /stories*/ and /blog*/ HTML ---
$targets = @()
$stories = Get-ChildItem -LiteralPath $ExportRoot -Recurse -File -Filter *.html | Where-Object {
  $_.FullName -match '\\stories(\\|/)|/stories(\\|/)'
}
$blog = Get-ChildItem -LiteralPath $ExportRoot -Recurse -File -Filter *.html | Where-Object {
  $_.FullName -match '\\blog(\\|/)|/blog(\\|/)'
}
$targets += $stories
$targets += $blog

if ($targets.Count -eq 0) {
  Write-Host "No /stories or /blog HTML files found under $ExportRoot." -ForegroundColor Yellow
  exit 0
}

$changed = 0
foreach ($f in $targets) {
  if (Fix-File -Path $f.FullName) { $changed++ }
}

Write-Host "Processed $($targets.Count) HTML files; changed $changed." -ForegroundColor Cyan
Write-Host "Done. You can now commit & deploy." -ForegroundColor Green
