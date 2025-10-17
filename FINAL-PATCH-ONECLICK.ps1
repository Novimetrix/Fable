# FINAL-PATCH-ONECLICK.ps1 — all-in-one (v5)
# v5: remove Elementor frontend/runtime by explicit IDs + earlier host/path/inline matchers
#     also keeps localhost scrub, srcset/sizes removal, emoji removal, UTF-8 (no BOM).

param([string]$Root='.')

$sw = [Diagnostics.Stopwatch]::StartNew()
$utf8 = New-Object System.Text.UTF8Encoding($false)

$include = @('*.html','*.htm','*.css','*.js','*.xml','*.json','*.txt','*.md')
$exclude = @('*.svg','*.png','*.jpg','*.jpeg','*.webp','*.gif','*.ico','*.woff','*.woff2','*.ttf','*.otf','*.eot','*.pdf','*.zip','*.gz','*.map')

$files = Get-ChildItem -Path $Root -Recurse -File -Include $include | Where-Object {
  $exclude -notcontains ('*' + $_.Extension.TrimStart('.').ToLower())
}

$ts=0; $tc=0; $lf=0; $sr=0; $err=0
$rmScriptLocal=0; $rmLinkLocal=0
$rmElementorSrc=0; $rmElementorInline=0; $rmLinkPreloadElem=0
$rmEmojiSrc=0; $rmEmojiInline=0
$rmElemIdScript=0; $rmElemIdInline=0

# Base fixes
$reLocal    = [regex]'(?i)https?://(?:localhost|127\.0\.0\.1)(?::\d+)?'
$reLocalENC = [regex]'(?i)https?%3A%2F%2F(?:localhost|127\.0\.0\.1)(?:%3A\d+)?'
$reSrcAttr  = [regex]'(?i)\s+(srcset|sizes|imagesrcset)=(".*?"|''.*?'')'

# Remove tags hitting localhost
$reScriptLocal = [regex]"(?is)<script[^>]+src\s*=\s*[""'][^""']*(?:localhost|127\.0\.0\.1)[^""']*[""'][^>]*>\s*</script\s*>"
$reLinkLocal   = [regex]"(?is)<link[^>]+href\s*=\s*[""'][^""']*(?:localhost|127\.0\.0\.1)[^""']*[""'][^>]*>"

# Elementor by path/host and inline signatures
$reElementorSrc = [regex]"(?is)<script\b[^>]*\bsrc\s*=\s*[""'][^""']*/wp-content/plugins/elementor/assets/js/[^""']*(frontend|min|runtime)[^""']*[""'][^>]*>\s*</script\s*>"
$reElementorInline = [regex]"(?is)<script\b[^>]*>\s*[^<]*(elementorFrontendConfig|elementorFrontend|elementor\.modules|__webpack_require__)[\s\S]*?</script\s*>"
$reLinkPreloadElem = [regex]"(?is)<link\b[^>]+\brel\s*=\s*[""']preload[""'][^>]+\bas\s*=\s*[""']script[""'][^>]+\bhref\s*=\s*[""'][^""']*/wp-content/plugins/elementor/assets/js/[^""']+[""'][^>]*>"

# Elementor by explicit IDs (covers typical WP enqueued handles)
$reElemIdScript = [regex]"(?is)<script\b[^>]+\bid\s*=\s*[""'](?:elementor-(?:pro-)?frontend-js|elementor-webpack-runtime-js)[""'][^>]*>\s*</script\s*>"
$reElemIdInline = [regex]"(?is)<script\b[^>]+\bid\s*=\s*[""'](?:elementor-(?:pro-)?frontend-js-(?:before|after|extra)|elementor-webpack-runtime-js-(?:before|after|extra))[""'][^>]*>[\s\S]*?</script\s*>"

# Emoji script & inline settings
$reEmojiSrc    = [regex]"(?is)<script\b[^>]*\bsrc\s*=\s*[""'][^""']*/wp-includes/js/wp-emoji-release\.min\.js[^""']*[""'][^>]*>\s*</script\s*>"
$reEmojiInline = [regex]"(?is)<script\b[^>]*>\s*[^<]*(wp-emoji|twemoji|emojiSettings)[\s\S]*?</script\s*>"

foreach ($f in $files) {
  try {
    $ts++
    $orig = Get-Content -Raw -Encoding UTF8 -LiteralPath $f.FullName
    $new = $orig

    # counts before
    $cLocal = ($reLocal.Matches($new).Count) + ($reLocalENC.Matches($new).Count)
    $cSrcA  = $reSrcAttr.Matches($new).Count
    $cScrL  = $reScriptLocal.Matches($new).Count
    $cLnkL  = $reLinkLocal.Matches($new).Count
    $cElemS = $reElementorSrc.Matches($new).Count
    $cElemI = $reElementorInline.Matches($new).Count
    $cElemP = $reLinkPreloadElem.Matches($new).Count
    $cElemIdS = $reElemIdScript.Matches($new).Count
    $cElemIdI = $reElemIdInline.Matches($new).Count
    $cEmoS  = $reEmojiSrc.Matches($new).Count
    $cEmoI  = $reEmojiInline.Matches($new).Count

    # strip whole tags first
    if ($cScrL -gt 0) { $new = $reScriptLocal.Replace($new, '') }
    if ($cLnkL -gt 0) { $new = $reLinkLocal.Replace($new, '') }
    if ($cElemS -gt 0) { $new = $reElementorSrc.Replace($new, '') }
    if ($cElemI -gt 0) { $new = $reElementorInline.Replace($new, '') }
    if ($cElemP -gt 0) { $new = $reLinkPreloadElem.Replace($new, '') }
    if ($cElemIdS -gt 0) { $new = $reElemIdScript.Replace($new, '') }
    if ($cElemIdI -gt 0) { $new = $reElemIdInline.Replace($new, '') }
    if ($cEmoS  -gt 0) { $new = $reEmojiSrc.Replace($new, '') }
    if ($cEmoI  -gt 0) { $new = $reEmojiInline.Replace($new, '') }

    # then clean localhost urls + responsive attrs
    $new = $reLocal.Replace($new, '')
    $new = $reLocalENC.Replace($new, '')
    $new = $reSrcAttr.Replace($new, '')

    if ($new -ne $orig) {
      [IO.File]::WriteAllText($f.FullName, $new, $utf8)
      $tc++
      $lf += $cLocal
      $sr += $cSrcA
      $rmScriptLocal += $cScrL
      $rmLinkLocal   += $cLnkL
      $rmElementorSrc += $cElemS
      $rmElementorInline += $cElemI
      $rmLinkPreloadElem += $cElemP
      $rmElemIdScript += $cElemIdS
      $rmElemIdInline += $cElemIdI
      $rmEmojiSrc += $cEmoS
      $rmEmojiInline += $cEmoI
    }
  } catch {
    $err++
  }
}

$sw.Stop()

$report = @(
  'FINAL-PATCH-ONECLICK finished. (v5)',
  ('Scanned files                         : {0}' -f $ts),
  ('Changed files                         : {0}' -f $tc),
  ('Localhost URL fixes                   : {0}' -f $lf),
  ('srcset/sizes removed                  : {0}' -f $sr),
  ('localhost <script> removed            : {0}' -f $rmScriptLocal),
  ('localhost <link> removed              : {0}' -f $rmLinkLocal),
  ('Elementor JS <script> removed (path)  : {0}' -f $rmElementorSrc),
  ('Elementor inline <script> removed     : {0}' -f $rmElementorInline),
  ('Elementor preload <link> removed      : {0}' -f $rmLinkPreloadElem),
  ('Elementor <script> removed (by id)    : {0}' -f $rmElemIdScript),
  ('Elementor inline removed (by id)      : {0}' -f $rmElemIdInline),
  ('wp-emoji-release <script> removed     : {0}' -f $rmEmojiSrc),
  ('wp-emoji inline settings removed      : {0}' -f $rmEmojiInline),
  ('Errors                                : {0}' -f $err),
  ('Elapsed                               : {0:n1}s' -f $sw.Elapsed.TotalSeconds)
)
$reportText = $report -join [Environment]::NewLine
$reportText | Write-Host

$logPath = Join-Path (Get-Location) 'FINAL-PATCH.log'
[IO.File]::WriteAllText($logPath, $reportText, $utf8)

Write-Host ''
Write-Host ('Report saved to: ' + $logPath)
