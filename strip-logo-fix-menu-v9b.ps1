# strip-logo-fix-menu-v9b.ps1
# Structural + targeted reveal:
#  - Remove logo <img> (custom-logo/site-logo/logo*).
#  - Remove "Skip to content" link.
#  - Force UL.menu bullets off inline.
#  - Tag nav blocks with data attribute and inline style visibility:hidden;
#    inject a tiny DOMContentLoaded script in <head> to reveal nav quickly.
# PowerShell 5 compatible.
param([switch]$MakeBackup = $true)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File

if ($files.Count -eq 0) { Write-Host "No HTML files found under $root" -ForegroundColor Yellow; exit 0 }

$backupDir = Join-Path $root "_striplogo_v9b_bak"
if ($MakeBackup) { if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null } }

# Regexes
$rxLogoImg = [regex]'(?is)<img[^>]*\b(class|id)\s*=\s*"[^"]*\b(custom-logo|site-logo|logo)\b[^"]*"[^>]*>'
$rxEmptyLogoLink = [regex]'(?is)<a[^>]*\bclass="[^"]*\b(custom-logo-link|logo-link|site-logo-link)\b[^"]*"[^>]*>\s*</a>'
$rxSkipLink = [regex]'(?is)<a[^>]*class="[^"]*\bskip-link\b[^"]*"[^>]*>.*?</a>'
$rxUlMenu  = [regex]'(?is)<ul(?<attrs>[^>]*\bclass="[^"]*\bmenu\b[^"]*"[^>]*)>'
$rxStyle   = [regex]'(?is)\sstyle="([^"]*)"'
# nav: add data-nm-preload and visibility hidden
$rxNav = [regex]'(?is)<nav(?<attrs>[^>]*?(?:\bclass="[^"]*ct-main-navigation[^"]*"|\brole="navigation"[^>]*)[^>]*)>'

$headInjectMarker = '<!-- NM_NAV_PRELOAD -->'
$headInject = @'
<!-- NM_NAV_PRELOAD -->
<script>document.addEventListener("DOMContentLoaded",function(){try{document.querySelectorAll("nav[data-nm-preload]").forEach(function(n){n.style.visibility="";n.removeAttribute("data-nm-preload");});}catch(e){}});</script>
'@

$changed = 0
foreach ($f in $files) {
  try {
    $html = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
    $orig = $html

    # 1) Remove logo images + empty logo links
    $html = $rxLogoImg.Replace($html, '')
    $html = $rxEmptyLogoLink.Replace($html, '')

    # 2) Remove skip-link
    $html = $rxSkipLink.Replace($html, '')

    # 3) Inline bullets off for UL.menu
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

    # 4) Tag nav with data-nm-preload + visibility:hidden
    $html = $rxNav.Replace($html, {
      param($m)
      $attrs = $m.Groups['attrs'].Value
      # ensure data-nm-preload present
      if ($attrs -notmatch 'data-nm-preload') { $attrs += ' data-nm-preload' }
      # add/merge style visibility:hidden
      if ($rxStyle.IsMatch($attrs)) {
        $attrs = $rxStyle.Replace($attrs, {
          param($m2)
          $existing = $m2.Groups[1].Value
          if ($existing -match 'visibility\s*:') {
            ' style="' + $existing + '"'
          } else {
            ' style="visibility:hidden;' + $existing + '"'
          }
        }, 1)
      } else {
        $attrs += ' style="visibility:hidden;"'
      }
      return '<nav' + $attrs + '>'
    })

    # 5) Ensure head has reveal script
    if ($html.IndexOf($headInjectMarker) -lt 0) {
      $idxHead = $html.IndexOf('</head>', [System.StringComparison]::OrdinalIgnoreCase)
      if ($idxHead -ge 0) {
        $html = $html.Substring(0, $idxHead) + "`n" + $headInject + "`n" + $html.Substring($idxHead)
      } else {
        $html = $headInject + $html
      }
    }

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
Write-Host ("strip-logo-fix-menu-v9b changed {0} file(s)." -f $changed) -ForegroundColor Green
Write-Host "Done."
