# nm-flashfix-v12e-nobak.ps1  — logo‑safe, no backups
$ErrorActionPreference = 'Stop'

$files = Get-ChildItem -Recurse -Include *.html, *.htm -File
if ($files.Count -eq 0) { Write-Host "No HTML files found."; exit 0 }

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

  # 1) Remove "Skip to content" link (keep everything else)
  $html = [regex]::Replace($html, '(?is)<a\s+class="skip-link[^"]*"\s+href="#main">.*?</a>', '')

  # 2) Inside ANY <nav ...>...</nav>, inline list reset for UL + LI
  $html = [regex]::Replace($html, '(?is)<nav\b[^>]*>.*?</nav>', {
    param($mNav)
    $block = $mNav.Value

    $block = [regex]::Replace($block, '(?is)<ul(?<a>[^>]*)>', {
      param($mUL)
      $attrs = $mUL.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
      '<ul' + $attrs + '>'
    })

    $block = [regex]::Replace($block, '(?is)<li(?<a>[^>]*)>', {
      param($mLI)
      $attrs = $mLI.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;margin:0;padding:0;'
      '<li' + $attrs + '>'
    })

    return $block
  })

  # 3) Safety passes for common menu ULs anywhere
  $html = [regex]::Replace($html, '(?is)<ul(?<a>[^>]*\bid="menu-main-menu"[^>]*)>', {
    param($mMain)
    $attrs = $mMain.Groups['a'].Value
    $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
    '<ul' + $attrs + '>'
  })

  $html = [regex]::Replace($html, '(?is)<ul(?<a>[^>]*\bclass="[^"]*\bmenu\b[^"]*"[^>]*)>', {
    param($mClass)
    $attrs = $mClass.Groups['a'].Value
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
