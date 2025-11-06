# nm-flashfix-v12d-nobak.ps1
$ErrorActionPreference = 'Stop'

# Recurse all exported HTML files
$files = Get-ChildItem -Recurse -Include *.html, *.htm -File
if ($files.Count -eq 0) {
  Write-Host "No HTML files found." -ForegroundColor Yellow
  exit 0
}

# Helpers
$rxStyle = New-Object regex '(?is)\sstyle="([^"]*)"'
function AddOrMerge([string]$attrs, [string]$css) {
  if ($rxStyle.IsMatch($attrs)) {
    return $rxStyle.Replace($attrs, { param($m) ' style="' + $css + $m.Groups[1].Value + '"' }, 1)
  } else {
    return $attrs + ' style="' + $css + '"'
  }
}

$patched = 0
foreach ($f in $files) {
  $html = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  $orig = $html

  # 1) Remove "Skip to content" anchor
  $html = [regex]::Replace($html, '(?is)<a\s+class="skip-link[^"]*"\s+href="#main">.*?</a>', '')

  # 2) Inline list reset inside desktop header nav only
  $html = [regex]::Replace($html, '(?is)<nav\b[^>]*id="header-menu-1"[^>]*>.*?</nav>', {
    param($mNav)
    $block = $mNav.Value

    # ULs
    $block = [regex]::Replace($block, '(?is)<ul(?<a>[^>]*)>', {
      param($mUL)
      $attrs = $mUL.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
      '<ul' + $attrs + '>'
    })
    # LIs
    $block = [regex]::Replace($block, '(?is)<li(?<a>[^>]*)>', {
      param($mLI)
      $attrs = $mLI.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;margin:0;padding:0;'
      '<li' + $attrs + '>'
    })

    return $block
  })

  # 3) Safety: ensure the main UL and any UL with class containing "menu" are reset
  $html = [regex]::Replace($html, '(?is)<ul(?<a>[^>]*\bid="menu-main-menu"[^>]*)>', {
    param($mMain)
    $attrs = $mMain.Groups['a'].Value
    $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
    '<ul' + $attrs + '>'
  })

  $html = [regex]::Replace($html, '(?is)<ul(?<a>[^>]*\bclass="[^"]*\bmenu\b[^"]*"[^>]*)>', {
    param($mClassMenu)
    $attrs = $mClassMenu.Groups['a'].Value
    $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
    '<ul' + $attrs + '>'
  })

  if ($html -ne $orig) {
    [System.IO.File]::WriteAllText($f.FullName, $html, (New-Object System.Text.UTF8Encoding($false)))
    $patched++
    Write-Host "patched: $($f.FullName)"
  }
}

Write-Host "Done. Files patched: $patched"
