$ErrorActionPreference='Stop'
$root = Get-Location
Write-Host "Working in $root"

# === 1) Rewrite ONLY text assets (NO .js) ===
$targets = Get-ChildItem -Recurse -File -Include *.html,*.htm,*.xml,*.css

$rules = @(
  @{p='https?://localhost:\d+/'; r='/' },
  @{p='https?://127\.0\.0\.1:\d+/'; r='/' },
  @{p='http%3A%2F%2Flocalhost%3A\d+%2F'; r='/' },
  @{p='http%3A%2F%2F127\.0\.0\.1%3A\d+%2F'; r='/' },
  # strip responsive attrs
  @{p='(\s)(srcset|imagesrcset)\s*=\s*"[^"]*"'; r='' },
  @{p="(\s)(srcset|imagesrcset)\s*=\s*'[^']*'"; r='' },
  @{p='(\s)sizes\s*=\s*"[^"]*"'; r='' },
  @{p="(\s)sizes\s*=\s*'[^']*'"; r='' },
  # collapse accidental multi-slashes but avoid protocol (handled by regex negative lookbehind for ':')
  @{p='(?<!:)/{2,}'; r='/' }
)

$changed = @()

foreach($f in $targets){
  $orig = [IO.File]::ReadAllText($f.FullName,[Text.UTF8Encoding]::new($false))
  $text = $orig
  foreach($rule in $rules){
    $text = [regex]::Replace($text, $rule.p, $rule.r)
  }
  if($text -ne $orig){
    [IO.File]::WriteAllText($f.FullName,$text,[Text.UTF8Encoding]::new($false))
    $changed += $f.FullName
  }
}

# === 2) Inject runtime guard (in HTML only) ===
$inject = @'
<script>
(function(){
  try{
    // remove srcset/sizes at runtime (defense in depth)
    var imgs = document.querySelectorAll('img[srcset],source[srcset]');
    imgs.forEach(function(el){ el.removeAttribute('srcset'); el.removeAttribute('sizes'); });
    // guard flag
    window.__noSrcsetActive = true;
  }catch(e){}
})();
</script>
'@

$htmlFiles = Get-ChildItem -Recurse -File -Include *.html,*.htm
foreach($h in $htmlFiles){
  $t = [IO.File]::ReadAllText($h.FullName,[Text.UTF8Encoding]::new($false))
  if($t -notmatch [regex]::Escape($inject)){
    if($t -match '</head>'){
      $t = $t -replace '</head>', ($inject + "`r`n</head>")
    } elseif($t -match '</body>'){
      $t = $t -replace '</body>', ($inject + "`r`n</body>")
    } else {
      $t += "`r`n$inject`r`n"
    }
    [IO.File]::WriteAllText($h.FullName,$t,[Text.UTF8Encoding]::new($false))
    $changed += $h.FullName
  }
}

# === 3) Summary (also excludes .js) ===
$localhostLeft = (Get-ChildItem -Recurse -File -Include *.html,*.htm,*.xml,*.css | Select-String -SimpleMatch 'localhost:' | Measure-Object).Count
$srcsetLeft = (Get-ChildItem -Recurse -File -Include *.html,*.htm,*.xml,*.css | Select-String -Pattern 'srcset=|imagesrcset=|sizes=' | Measure-Object).Count

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host ("  Files changed: {0}" -f ($changed | Select-Object -Unique | Measure-Object).Count)
Write-Host ("  localhost refs left (html/xml/css): {0}" -f $localhostLeft)
Write-Host ("  srcset/sizes left (html/css): {0}" -f $srcsetLeft)
Write-Host "Done."
