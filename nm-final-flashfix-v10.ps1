# nm-final-flashfix-v10.ps1
# Tailored for your Blocksy export:
# - Keep only the FIRST <a class="site-logo-container">...</a> in the file; remove the rest.
# - Remove the "Skip to content" <a class="skip-link ...>...</a>.
# - Add inline 'list-style:none;padding-left:0;margin:0;' to all <ul class="menu"...>.
param([switch]$MakeBackup = $true)
$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File
if($files.Count -eq 0){ Write-Host "No HTML files found."; exit 0 }

$backupDir = Join-Path $root "_nm_flashfix_v10_bak"
if($MakeBackup){ if(-not(Test-Path $backupDir)){ New-Item -ItemType Directory -Path $backupDir | Out-Null } }

$rxSkip = [regex]'(?is)<a[^>]*\bclass="[^"]*\bskip-link\b[^"]*"[^>]*>.*?</a>'
$rxUL   = [regex]'(?is)<ul(?<attrs>[^>]*\bclass="[^"]*\bmenu\b[^"]*"[^>]*)>'
$rxStyle= [regex]'(?is)\sstyle="([^"]*)"'
$rxLogoBlock = [regex]'(?is)<a[^>]*\bclass="[^"]*\bsite-logo-container\b[^"]*"[^>]*>.*?</a>'

foreach($f in $files){
  $html = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
  $orig = $html

  # Remove extra logo blocks (keep first)
  $matches = $rxLogoBlock.Matches($html)
  if($matches.Count -gt 1){
    for($i=1;$i -lt $matches.Count;$i++){
      $html = $html.Remove($matches[$i].Index, $matches[$i].Length)
      # After removal, indexes shift; recompute matches
      $matches = $rxLogoBlock.Matches($html)
      if($matches.Count -le 1){ break }
      $i = 0
    }
  }

  # Remove skip link(s)
  $html = $rxSkip.Replace($html,'')

  # Add inline styles to UL.menu
  $html = $rxUL.Replace($html, {
    param($m)
    $attrs = $m.Groups['attrs'].Value
    if($rxStyle.IsMatch($attrs)){
      $attrs = $rxStyle.Replace($attrs, {
        param($m2)
        $existing = $m2.Groups[1].Value
        ' style="list-style:none;padding-left:0;margin:0;' + $existing + '"'
      },1)
    } else {
      $attrs += ' style="list-style:none;padding-left:0;margin:0;"'
    }
    return '<ul' + $attrs + '>'
  })

  if($html -ne $orig){
    if($MakeBackup){
      $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
      $dest = Join-Path $backupDir $rel
      $dir = Split-Path -Parent $dest
      if(-not(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir | Out-Null }
      Copy-Item -Path $f.FullName -Destination $dest -Force
    }
    [System.IO.File]::WriteAllText($f.FullName,$html,$utf8NoBom)
    Write-Host ("Patched " + $f.Name) -ForegroundColor Green
  }
}
Write-Host "Done."
