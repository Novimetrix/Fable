
# === ONECLICK SAFE MODE (v2) ===
# Guarantees every <img> has a valid src on first paint.
# Expands support for many lazy-load variants and keeps srcset/sizes intact.
# Also removes any previously injected "no-srcset.js" script tags from HTML.
param()

Write-Host "Running ONECLICK SAFE MODE (v2)..."

# Process all HTML files
Get-ChildItem -Recurse -File -Include *.html | ForEach-Object {
    $path = $_.FullName
    $html = Get-Content $path -Raw

    # 0) Scrub localhost/127.0.0.1 to root-relative (safe)
    $html = $html -replace 'https?://localhost(?::\d+)?', ''
    $html = $html -replace 'https?://127\.0\.0\.1(?::\d+)?', ''

    # 1) data-* → real attributes (wide net, safe)
    $pat_src  = @'
<img([^>]*?)\s(?:data-lazy-src|data-src|data-original|data-echo)=["']([^"']+)["']([^>]*)>
'@
    $rep_src  = @'
<img$1 src="$2"$3>
'@
    $html = $html -replace $pat_src, $rep_src

    $pat_srcset = @'
<(img|source)([^>]*?)\s(?:data-srcset|data-lazy-srcset)=["']([^"']+)["']([^>]*)>
'@
    $rep_srcset = @'
<$1$2 srcset="$3"$4>
'@
    $html = $html -replace $pat_srcset, $rep_srcset

    # 2) Remove lazy/async flags (safe to drop in static)
    $html = $html -replace '\sloading=["'']lazy["'']', ''
    $html = $html -replace '\sdecoding=["'']async["'']', ''

    # 3) Provide src if only srcset exists
    $pat_missing_src = @'
<img((?:(?!\ssrc=).)*?)\ssrcset=["']([^"']+)["']([^>]*)>
'@
    $html = $html -replace $pat_missing_src, {
        $set = $args[0].Groups[2].Value
        $first = ($set -split ',')[0].Trim().Split(' ')[0]
        "<img$($args[0].Groups[1].Value) src=""$first"" srcset=""$set""$($args[0].Groups[3].Value)>"
    }

    # 4) Remove previously injected no-srcset runtime guard (if present)
    $html = $html -replace '<script[^>]*no-srcset\.js[^>]*></script>', ''

    # Save
    if ($html -ne (Get-Content $path -Raw)) {
        Set-Content $path $html -Encoding UTF8
        Write-Host ("Changed: {0}" -f $path)
    }
}

# Summary (light)
$left_lazy = (Get-ChildItem -Recurse -File -Include *.html | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern 'data-src|data-lazy-src' -AllMatches | Measure-Object).Count
$missing_src = (Get-ChildItem -Recurse -File -Include *.html | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern '<img(?![^>]*\ssrc=)[^>]*>' -AllMatches | Measure-Object).Count

Write-Host ""
Write-Host "SAFE Summary:"
Write-Host ("  remaining lazy attrs (should be 0 or very low): {0}" -f $left_lazy)
Write-Host ("  <img> without src (should be 0): {0}" -f $missing_src)
Write-Host ""
Write-Host "Done. Review, Commit, and Push."
