# === ONECLICK FINAL (Unified v3) ===
# Purpose: Guarantee every <img> has a valid src on first paint for static exports,
# while preserving performance (lazy-loading, responsive srcset).
# What it does:
#   - Scrubs localhost/127.0.0.1 (and URL-encoded forms) to root-relative.
#   - Converts lazy variants → real attrs:
#       data-src, data-lazy-src, data-original, data-echo  → src
#       data-srcset, data-lazy-srcset                      → srcset
#   - If an <img> has only srcset, adds a src using the SMALLEST candidate.
#   - Removes any previously injected no-srcset runtime guard.
#   - Leaves loading="lazy" and decoding="async" intact (better LCP).
param()

Write-Host "Running ONECLICK FINAL..."

# Process all HTML files
Get-ChildItem -Recurse -File -Include *.html | ForEach-Object {
    $path = $_.FullName
    $orig = Get-Content $path -Raw
    $html = $orig

    # 0) Scrub localhost/127.0.0.1 (plain & URL-encoded) to root-relative
    $html = $html -replace 'https?://localhost(?::\d+)?', ''
    $html = $html -replace 'https?://127\.0\.0\.1(?::\d+)?', ''
    $html = $html -replace 'http%3A%2F%2Flocalhost(?::\d+)?', ''
    $html = $html -replace 'http%3A%2F%2F127%2E0%2E0%2E1(?::\d+)?', ''

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

    # 2) If <img> has srcset but no src, assign the SMALLEST candidate as src
    $pat_missing_src = @'
<img((?:(?!\ssrc=).)*?)\ssrcset=["']([^"']+)["']([^>]*)>
'@
    $html = $html -replace $pat_missing_src, {
        $set = $args[0].Groups[2].Value
        # Choose smallest candidate by descriptor (w/x). Fallback to first URL.
        $bestUrl = $null
        $bestVal = [double]::PositiveInfinity
        foreach($part in ($set -split ',')) {
            $p = $part.Trim()
            if(-not $p) { continue }
            $pieces = $p -split '\s+'
            $url = $pieces[0]
            if($pieces.Count -ge 2) {
                $desc = $pieces[1]
                if($desc -match '^(\d+(?:\.\d+)?)w$') {
                    $val = [double]$matches[1]
                } elseif($desc -match '^(\d+(?:\.\d+)?)x$') {
                    $val = [double]$matches[1] * 1000  # rough scale
                } else {
                    $val = 1e9
                }
            } else {
                $val = 1e9
            }
            if($val -lt $bestVal) { $bestVal = $val; $bestUrl = $url }
        }
        if(-not $bestUrl) { $bestUrl = ($set -split ',')[0].Trim().Split(' ')[0] }
        "<img$($args[0].Groups[1].Value) src=""$bestUrl"" srcset=""$set""$($args[0].Groups[3].Value)>"
    }

    # 3) Remove previously injected no-srcset runtime guard (if present)
    $html = $html -replace '<script[^>]*no-srcset\.js[^>]*></script>', ''

    if ($html -ne $orig) {
        Set-Content $path $html -Encoding UTF8
        Write-Host ("Changed: {0}" -f $path)
    }
}

# Summary
$left_lazy = (Get-ChildItem -Recurse -File -Include *.html | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern 'data-src|data-lazy-src|data-original|data-echo' -AllMatches | Measure-Object).Count
$missing_src = (Get-ChildItem -Recurse -File -Include *.html | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern '<img(?![^>]*\ssrc=)[^>]*>' -AllMatches | Measure-Object).Count

Write-Host ""
Write-Host "ONECLICK FINAL Summary:"
Write-Host ("  remaining lazy attrs (should be 0 or very low): {0}" -f $left_lazy)
Write-Host ("  <img> without src (should be 0): {0}" -f $missing_src)
Write-Host ""
Write-Host "Done. Review, Commit, and Push."
