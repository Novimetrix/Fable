# strip-bullets-nav-or-menu-v11b.ps1
# Purpose: Permanently remove bullets from navigation in exported HTML.
# Targets:
#   1) Any <ul>/<ol>/<li> inside <nav ...> ... </nav> blocks (anywhere in the file)
#   2) Any <ul> with class containing "menu" (global) — adds inline list-style:none; padding-left:0; margin:0;
# Backup: Creates _strip_bullets_v11b_bak by default.
param([switch]$MakeBackup = $true)

$ErrorActionPreference = 'Stop'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File

if ($files.Count -eq 0) {
  Write-Host "No HTML files found under $root" -ForegroundColor Yellow
  exit 0
}

# Backup folder
$backupDir = Join-Path $root "_strip_bullets_v11b_bak"
if ($MakeBackup) {
  if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
}

# Regex helpers
$rxNav    = [regex]'(?is)<nav\b[^>]*>.*?</nav>'
$rxUL     = [regex]'(?is)<ul(?<attrs>[^>]*)>'
$rxOL     = [regex]'(?is)<ol(?<attrs>[^>]*)>'
$rxLI     = [regex]'(?is)<li(?<attrs>[^>]*)>'
$rxStyle  = [regex]'(?is)\sstyle="([^"]*)"'
$rxULMenu = [regex]'(?is)<ul(?<attrs>[^>]*\bclass="[^"]*\bmenu\b[^"]*"[^>]*)>'

function AddOrMergeStyle([string]$attrs, [string]$cssToAdd) {
  if ($rxStyle.IsMatch($attrs)) {
    return $rxStyle.Replace($attrs, {
      param($m)
      $existing = $m.Groups[1].Value
      ' style="' + $cssToAdd + $existing + '"'
    }, 1)
  } else {
    return $attrs + ' style="' + $cssToAdd + '"'
  }
}

$changed = 0

foreach ($f in $files) {
  try {
    $html = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
    $orig = $html

    # Pass 1: inside each <nav>...</nav>, inline no-bullets
    $html = $rxNav.Replace($html, {
      param($mNav)
      $block = $mNav.Value

      $block = $rxUL.Replace($block, {
        param($mUL)
        $attrs = $mUL.Groups['attrs'].Value
        $attrs = AddOrMergeStyle $attrs 'list-style:none;padding-left:0;margin:0;'
        '<ul' + $attrs + '>'
      })

      $block = $rxOL.Replace($block, {
        param($mOL)
        $attrs = $mOL.Groups['attrs'].Value
        $attrs = AddOrMergeStyle $attrs 'list-style:none;padding-left:0;margin:0;'
        '<ol' + $attrs + '>'
      })

      $block = $rxLI.Replace($block, {
        param($mLI)
        $attrs = $mLI.Groups['attrs'].Value
        $attrs = AddOrMergeStyle $attrs 'list-style:none;margin:0;padding:0;'
        '<li' + $attrs + '>'
      })

      $block
    })

    # Pass 2: any <ul class="...menu..."> globally
    $html = $rxULMenu.Replace($html, {
      param($mULm)
      $attrs = $mULm.Groups['attrs'].Value
      $attrs = AddOrMergeStyle $attrs 'list-style:none;padding-left:0;margin:0;'
      '<ul' + $attrs + '>'
    })

    if ($html -ne $orig) {
      if ($MakeBackup) {
        $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
        $destPath = Join-Path $backupDir $rel
        $destDir = Split-Path -Parent $destPath
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
        Copy-Item -Path $f.FullName -Destination $destPath -Force
      }
      [System.IO.File]::WriteAllText($f.FullName, $html, $utf8NoBom)
      $changed++
    }
  } catch {
    Write-Warning ("Failed {0}: {1}" -f $f.FullName, $_.Exception.Message)
  }
}

Write-Host ("strip-bullets-nav-or-menu-v11b updated {0} file(s)." -f $changed) -ForegroundColor Green
Write-Host "Done."
