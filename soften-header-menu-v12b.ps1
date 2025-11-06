# soften-header-menu-v12b.ps1
# Keeps nav, kills skip-link, and inlines no-bullet styles so the menu doesn't flash.
# - Removes the "Skip to content" anchor
# - Adds inline list-style:none; padding-left:0; margin:0; to UL/OL/LI inside any <nav>…</nav>
# - Also enforces same styles on <ul id="menu-main-menu"> globally
# - Creates .bak backups next to modified files
$files = Get-ChildItem -Recurse -Include *.html
foreach ($f in $files) {
  $html = Get-Content -LiteralPath $f.FullName -Raw
  $orig = $html

  # 1) Remove skip-link
  $html = [regex]::Replace($html, '(?is)<a\s+class="skip-link[^"]*"\s+href="#main">.*?</a>', '')

  # Helpers
  $rxStyle = New-Object regex '(?is)\sstyle="([^"]*)"'

  function AddOrMerge([string]$attrs, [string]$css) {
    if ($rxStyle.IsMatch($attrs)) {
      return $rxStyle.Replace($attrs, { param($m) ' style="' + $css + $m.Groups[1].Value + '"' }, 1)
    } else {
      return $attrs + ' style="' + $css + '"'
    }
  }

  # 2) Inside each <nav>…</nav>, inline list reset
  $html = [regex]::Replace($html, '(?is)<nav\b[^>]*>.*?</nav>', {
    param($mNav)
    $block = $mNav.Value
    $block = [regex]::Replace($block, '(?is)<ul(?<a>[^>]*)>', { param($mUL)
      $attrs = $mUL.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
      '<ul' + $attrs + '>'
    })
    $block = [regex]::Replace($block, '(?is)<ol(?<a>[^>]*)>', { param($mOL)
      $attrs = $mOL.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;padding-left:0;margin:0;'
      '<ol' + $attrs + '>'
    })
    $block = [regex]::Replace($block, '(?is)<li(?<a>[^>]*)>', { param($mLI)
      $attrs = $mLI.Groups['a'].Value
      $attrs = AddOrMerge $attrs 'list-style:none;margin:0;padding:0;'
      '<li' + $attrs + '>'
    })
    return $block
  })

  # 3) Global safety: target <ul id="menu-main-menu">
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
