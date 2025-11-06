# soften-desktop-nav-v12c.ps1
# Purpose: Keep desktop nav visible but prevent bullet flash by inlining styles
# Scope:   Only inside <nav id="header-menu-1">…</nav> blocks and on <ul id="menu-main-menu">
# Backup:  Creates .bak next to modified files
$files = Get-ChildItem -Recurse -Include *.html, *.htm -File
foreach ($f in $files) {
  $html = Get-Content -LiteralPath $f.FullName -Raw
  $orig = $html

  $rxStyle = New-Object regex '(?is)\sstyle="([^"]*)"'
  function AddOrMerge([string]$attrs, [string]$css) {
    if ($rxStyle.IsMatch($attrs)) {
      return $rxStyle.Replace($attrs, { param($m) ' style="' + $css + $m.Groups[1].Value + '"' }, 1)
    } else {
      return $attrs + ' style="' + $css + '"'
    }
  }

  # 1) Inside desktop header nav only
  $html = [regex]::Replace($html, '(?is)<nav\b[^>]*id="header-menu-1"[^>]*>.*?</nav>', {
    param($mNav)
    $block = $mNav.Value

    # Add inline to ULs
    $block = [regex]::Replace($block, '(?is)<ul(?<a>[^>]*)>', {
      param($mUL)
      $attrs = $mUL.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
      '<ul' + $attrs + '>'
    })

    # Add inline to LIs
    $block = [regex]::Replace($block, '(?is)<li(?<a>[^>]*)>', {
      param($mLI)
      $attrs = $mLI.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;margin:0;padding:0;'
      '<li' + $attrs + '>'
    })

    return $block
  })

  # 2) Safety: ensure the main UL has it even outside of nav match
  $html = [regex]::Replace($html, '(?is)<ul(?<a>[^>]*\bid="menu-main-menu"[^>]*)>', {
    param($mMain)
    $attrs = $mMain.Groups['a'].Value
    $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
    '<ul' + $attrs + '>'
  })

  if ($html -ne $orig) {
    Copy-Item -LiteralPath $f.FullName -Destination ($f.FullName + '.bak') -Force
    Set-Content -LiteralPath $f.FullName -Value $html -Encoding UTF8
    Write-Host "patched: $($f.FullName)"
  }
}
Write-Host "Done."
Read-Host "Press any key to exit..."
