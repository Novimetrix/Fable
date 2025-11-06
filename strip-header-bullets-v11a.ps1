# strip-header-bullets-v11a.ps1
param([switch]$MakeBackup = $true)
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File
if ($files.Count -eq 0) { Write-Host "No HTML files found under $root" -ForegroundColor Yellow; exit 0 }
$backupDir = Join-Path $root "_strip_header_bullets_v11a_bak"
if ($MakeBackup) { if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null } }
$rxHeader = [regex]'(?is)<header\b[^>]*>.*?</header>'
$rxUL     = [regex]'(?is)<ul(?<attrs>[^>]*)>'
$rxOL     = [regex]'(?is)<ol(?<attrs>[^>]*)>'
$rxLI     = [regex]'(?is)<li(?<attrs>[^>]*)>'
$rxStyle  = [regex]'(?is)\sstyle="([^"]*)"'
function AddOrMergeStyle([string]$attrs, [string]$cssToAdd) {
  if ($rxStyle.IsMatch($attrs)) {
    return $rxStyle.Replace($attrs, { param($m) $existing = $m.Groups[1].Value; ' style="' + $cssToAdd + $existing + '"' }, 1)
  } else {
    return $attrs + ' style="' + $cssToAdd + '"'
  }
}
$changed = 0
foreach ($f in $files) {
  try {
    $html = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
    $orig = $html
    $html = $rxHeader.Replace($html, { param($mHeader)
      $block = $mHeader.Value
      $block = $rxUL.Replace($block, { param($mUL) $attrs = $mUL.Groups['attrs'].Value; $attrs = AddOrMergeStyle $attrs 'list-style:none;padding-left:0;margin:0;'; '<ul' + $attrs + '>' })
      $block = $rxOL.Replace($block, { param($mOL) $attrs = $mOL.Groups['attrs'].Value; $attrs = AddOrMergeStyle $attrs 'list-style:none;padding-left:0;margin:0;'; '<ol' + $attrs + '>' })
      $block = $rxLI.Replace($block, { param($mLI) $attrs = $mLI.Groups['attrs'].Value; $attrs = AddOrMergeStyle $attrs 'list-style:none;margin:0;padding:0;'; '<li' + $attrs + '>' })
      $block
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
Write-Host ("strip-header-bullets-v11a updated {0} file(s)." -f $changed) -ForegroundColor Green
Write-Host "Done."
