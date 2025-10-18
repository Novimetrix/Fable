# === ONECLICK FINAL (Unified v3 — syntax fixed) ===
# Ensures every <img> has a valid src on first paint for static exports,
# while keeping performance (lazy-loading + srcset). Works on Windows PowerShell 5+.
param()

Write-Host "Running ONECLICK FINAL (syntax-fixed)..."

# Gather all HTML files
$files = Get-ChildItem -Recurse -File -Include *.html

foreach ($f in $files) {
    $path = $f.FullName
    $orig = Get-Content $path -Raw
    $html = $orig

    # 0) Scrub localhost/127.0.0.1 (plain & URL-encoded) to root-relative
    $html = $html -replace 'https?://localhost(?::\d+)?', ''
    $html = $html -replace 'https?://127\.0\.0\.1(?::\d+)?', ''
    $html = $html -replace 'http%3A%2F%2Flocalhost(?::\d+)?', ''
    $html = $html -replace 'http%3A%2F%2F127%2E0%2E0%2E1(?::\d+)?', ''

    # 1) data-* → real attributes (src and srcset)
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
    $html = [regex]::Replace($html, $pat_missing_src, {
        param($m)
        $set = $m.Groups[2].Value
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
                    $val = [double]$matches[1] * 1000
                } else {
                    $val = 1e9
                }
            } else {
                $val = 1e9
            }
            if($val -lt $bestVal) { $bestVal = $val; $bestUrl = $url }
        }
        if(-not $bestUrl) { $bestUrl = ($set -split ',')[0].Trim().Split(' ')[0] }
        return "<img{0} src=""{1}"" srcset=""{2}""{3}>" -f $m.Groups[1].Value, $bestUrl, $set, $m.Groups[3].Value
    })

    # 3) Remove previously injected no-srcset runtime guard (if present)
    $html = $html -replace '<script[^>]*no-srcset\.js[^>]*></script>', ''

    # 3b) Ensure <img src> is root-relative (fix 'wp-content/...' without leading slash)
    $pat_rel_src = @'
<img([^>]*?)\ssrc=["'](?!https?:|/|data:|#)([^"']+)["']([^>]*?)>
'@
    $html = [regex]::Replace($html, $pat_rel_src, {
        param($m)
        $before = $m.Groups[1].Value
        $url    = $m.Groups[2].Value
        $after  = $m.Groups[3].Value
        if($url -match '^(?:\./|\.\./)+') {
            $url = $url -replace '^(?:\./|\.\./)+', ''
        }
        if($url -notmatch '^(?:https?:|/|data:|#)') {
            $url = '/' + $url
        }
        return "<img{0} src=""{1}""{2}>" -f $before, $url, $after
    })

    if ($html -ne $orig) {
        Set-Content $path $html -Encoding UTF8
        Write-Host ("Changed: {0}" -f $path)
    }
}

# Summary
$left_lazy = ($files | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern 'data-src|data-lazy-src|data-original|data-echo' -AllMatches | Measure-Object).Count
$missing_src = ($files | % { (Get-Content $_.FullName -Raw) } | Select-String -Pattern '<img(?![^>]*\ssrc=)[^>]*>' -AllMatches | Measure-Object).Count

Write-Host ""
Write-Host "ONECLICK FINAL Summary:"
Write-Host ("  remaining lazy attrs (should be 0 or very low): {0}" -f $left_lazy)
Write-Host ("  <img> without src (should be 0): {0}" -f $missing_src)
Write-Host ""
Write-Host "Done. Review, Commit, and Push."
