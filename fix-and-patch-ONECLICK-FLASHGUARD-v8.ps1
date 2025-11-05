# fix-and-patch-ONECLICK-FLASHGUARD-v8.ps1
# Structural patch: remove alternate logo <img> tags, hide bullets by styling UL.menu inline,
# and remove the "Skip to content" link entirely. No JS. Permanent in exported HTML.
param([switch]$MakeBackup = $false)

$ErrorActionPreference = 'Stop'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File

if ($files.Count -eq 0) { Write-Host "No HTML files found under $root" -ForegroundColor Yellow; exit 0 }

$backupDir = Join-Path $root "_flashguard_v8_bak"
if ($MakeBackup) { if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null } }

$altLogoRegex = [regex]'(?is)<img[^>]*(?:\sdata-logo\s*=\s*"(?:sticky|dark|transparent|mobile)")\b[^>]*>'
$skipLinkRegex = [regex]'(?is)<a[^>]*class="[^"]*\bskip-link\b[^"]*"[^>]*>.*?</a>'
# <ul ... class="... menu ...">  -> ensure inline style list-style:none;padding-left:0;margin:0;
$ulMenuRegex  = [regex]'(?is)<ul(?<attrs>[^>]*\bclass="[^"]*\bmenu\b[^"]*"[^>]*)>'
$styleRegex   = [regex]'(?is)\sstyle="([^"]*)"'

$fresh = 0
foreach ($f in $files) {
  try {
    $content = Get-Content -Path $f.FullName -Raw -Encoding UTF8

    $orig = $content

    # 1) Remove alternate logo images
    $content = $altLogoRegex.Replace($content, '')

    # 2) Remove the "skip to content" link
    $content = $skipLinkRegex.Replace($content, '')

    # 3) Normalize UL.menu bullets inline
    $content = $ulMenuRegex.Replace($content, {
        param($m)
        $attrs = $m.Groups['attrs'].Value
        $styled = $attrs
        if ($styleRegex.IsMatch($attrs)) {
            $styled = $styleRegex.Replace($attrs, {
                param($m2)
                $existing = $m2.Groups[1].Value
                ' style="list-style:none;padding-left:0;margin:0;' + $existing + '"'
            }, 1)
        } else {
            $styled = $attrs + ' style="list-style:none;padding-left:0;margin:0;"'
        }
        return '<ul' + $styled + '>'
    })

    if ($content -ne $orig) {
      if ($MakeBackup) {
        $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
        $destPath = Join-Path $backupDir $rel
        $destDir = Split-Path -Parent $destPath
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
        Copy-Item -Path $f.FullName -Destination $destPath -Force
      }
      [System.IO.File]::WriteAllText($f.FullName, $content, $utf8NoBom)
      $fresh++
    }
  } catch {
    Write-Warning ("Failed {0}: {1}" -f $f.FullName, $_.Exception.Message)
  }
}

Write-Host ("NM FlashGuard v8 rewrote {0} file(s)." -f $fresh) -ForegroundColor Green
Write-Host "Done."
