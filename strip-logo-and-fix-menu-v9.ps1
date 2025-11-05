# strip-logo-and-fix-menu-v9.ps1
# Ultra-safe export pass:
#  - Permanently removes header logo <img> elements (custom-logo/site-logo/logo*).
#  - Cleans up empty logo links.
#  - Forces <ul class="menu"> to have inline list-style:none to stop bullet flash without timing.
#  - No JS injected. PowerShell 5 compatible.
# Usage: powershell -ExecutionPolicy Bypass -File .\strip-logo-and-fix-menu-v9.ps1
param([switch]$MakeBackup = $true)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File

if ($files.Count -eq 0) { Write-Host "No HTML files found under $root" -ForegroundColor Yellow; exit 0 }

# Backups
$backupDir = Join-Path $root "_striplogo_v9_bak"
if ($MakeBackup) { if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null } }

# Regexes
# Remove any <img> whose class/id/name hints at logo inside the document (esp. header)
$rxLogoImg = [regex]'(?is)<img[^>]*\b(class|id)\s*=\s*"[^"]*\b(custom-logo|site-logo|logo)\b[^"]*"[^>]*>'
# Remove empty anchor wrappers like <a class="custom-logo-link">   </a>
$rxEmptyLogoLink = [regex]'(?is)<a[^>]*\bclass="[^"]*\b(custom-logo-link|logo-link|site-logo-link)\b[^"]*"[^>]*>\s*</a>'
# Inline styles for menu ULs
$rxUlMenu  = [regex]'(?is)<ul(?<attrs>[^>]*\bclass="[^"]*\bmenu\b[^"]*"[^>]*)>'
$rxStyle   = [regex]'(?is)\sstyle="([^"]*)"'

$changed = 0
foreach ($f in $files) {
  try {
    $html = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
    $orig = $html

    # 1) Remove logo images
    $html = $rxLogoImg.Replace($html, '')

    # 2) Remove now-empty logo links
    $html = $rxEmptyLogoLink.Replace($html, '')

    # 3) Force UL.menu bullets off inline
    $html = $rxUlMenu.Replace($html, {
      param($m)
      $attrs = $m.Groups['attrs'].Value
      if ($rxStyle.IsMatch($attrs)) {
        $attrs = $rxStyle.Replace($attrs, {
          param($m2)
          $existing = $m2.Groups[1].Value
          ' style="list-style:none;padding-left:0;margin:0;' + $existing + '"'
        }, 1)
      } else {
        $attrs += ' style="list-style:none;padding-left:0;margin:0;"'
      }
      return '<ul' + $attrs + '>'
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

Write-Host ("strip-logo-and-fix-menu-v9 changed {0} file(s)." -f $changed) -ForegroundColor Green
Write-Host "Done."
