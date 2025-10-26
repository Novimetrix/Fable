# mojibake-fixer-ULTRA2-HTMLONLY.ps1 (close patch)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSCommandPath
if (-not (Test-Path $Root)) { Write-Host "Folder not found: $Root" -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }

$cp1252 = [System.Text.Encoding]::GetEncoding(1252)
$utf8   = [System.Text.Encoding]::UTF8

Write-Host "Scanning (HTML only): $Root" -ForegroundColor Cyan
$files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in @('.html','.htm') } | Sort-Object FullName
$tot = $files.Count
Write-Host ("Found {0} HTML files" -f $tot)

$changed = 0; $injected = 0; $i = 0
foreach($f in $files){
  $i++
  Write-Host ("[{0}/{1}] {2}" -f $i, $tot, $f.FullName)
  try {
    $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $fixed = $utf8.GetString($cp1252.GetBytes($txt))

    $didInject = $false
    if ($fixed.IndexOf('<meta charset="utf-8"', [StringComparison]::OrdinalIgnoreCase) -lt 0) {
      $headIdx = $fixed.IndexOf('<head', [StringComparison]::OrdinalIgnoreCase)
      if ($headIdx -ge 0) {
        $gt = $fixed.IndexOf('>', $headIdx)
        if ($gt -ge 0) {
          $fixed = $fixed.Insert($gt+1, "`r`n<meta charset=""utf-8"">")
          $didInject = $true
        }
      }
    }

    if ($fixed -ne $txt -or $didInject) {
      Set-Content -LiteralPath $f.FullName -Value $fixed -Encoding UTF8
      if($didInject){ $injected++ }
      $changed++
    }
  } catch {
    Write-Host ("Error: {0} -> {1}" -f $f.FullName, $_) -ForegroundColor Red
  }
}

Write-Host ("Done. Files changed: {0}, meta injected: {1}" -f $changed, $injected) -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to close"
exit
