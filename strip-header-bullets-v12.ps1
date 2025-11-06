# strip-header-bullets-v12.ps1
# Removes 'Skip to content' and desktop header nav from exported HTML files.
# Creates .bak backups next to modified files.
$files = Get-ChildItem -Recurse -Include *.html
foreach ($f in $files) {
  $html = Get-Content -LiteralPath $f.FullName -Raw
  $orig = $html
  # Remove skip-link anchor
  $html = [regex]::Replace($html, '(?is)<a\s+class="skip-link[^"]*"\s+href="#main">.*?</a>', '')
  # Remove header nav
  $html = [regex]::Replace($html, '(?is)<nav[^>]*id="header-menu-1"[^>]*>.*?</nav>', '')
  # Remove main menu UL fallback
  $html = [regex]::Replace($html, '(?is)<ul[^>]*id="menu-main-menu"[^>]*>.*?</ul>', '')
  if ($html -ne $orig) {
    Copy-Item -LiteralPath $f.FullName -Destination ($f.FullName + '.bak') -Force
    Set-Content -LiteralPath $f.FullName -Value $html -Encoding UTF8
    Write-Host "patched: $($f.FullName)"
  }
}
Write-Host "Done."
Read-Host "Press any key to exit..."
