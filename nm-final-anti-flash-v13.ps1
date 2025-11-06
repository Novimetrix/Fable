# nm-final-anti-flash-v13.ps1 — no backups
$ErrorActionPreference = 'Stop'

$files = Get-ChildItem -Recurse -Include *.html, *.htm -File
if ($files.Count -eq 0) { Write-Host "No HTML files found."; exit 0 }

$headInject = @'
<!-- NM_ANTI_FLASH_v13 -->
<style>nav#header-menu-1{visibility:hidden}</style>
<script>document.addEventListener("DOMContentLoaded",function(){var n=document.getElementById("header-menu-1");if(n)n.style.visibility="";});</script>
'@

$patched=0
foreach($f in $files){
  $html = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  $orig = $html

  # 1) Remove skip link
  $html = [regex]::Replace($html,'(?is)<a\s+class="skip-link[^"]*"\s+href="#main">.*?</a>','')

  # 2) Inline no-bullets within nav#header-menu-1
  $rxStyle = New-Object regex '(?is)\sstyle="([^"]*)"'
  function AddOrMerge([string]$attrs,[string]$css){
    if($rxStyle.IsMatch($attrs)){
      return $rxStyle.Replace($attrs,{ param($m) ' style="' + $css + $m.Groups[1].Value + '"' },1)
    } else { return $attrs + ' style="' + $css + '"' }
  }
  $html = [regex]::Replace($html,'(?is)<nav\b[^>]*id="header-menu-1"[^>]*>.*?</nav>',{
    param($mNav)
    $b = $mNav.Value
    $b = [regex]::Replace($b,'(?is)<ul(?<a>[^>]*)>',{ param($mUL) $a=$mUL.Groups['a'].Value; $a=AddOrMerge $a 'list-style:none;padding-left:0;margin:0;'; '<ul'+$a+'>' })
    $b = [regex]::Replace($b,'(?is)<li(?<a>[^>]*)>',{ param($mLI) $a=$mLI.Groups['a'].Value; $a=AddOrMerge $a 'list-style:none;margin:0;padding:0;'; '<li'+$a+'>' })
    return $b
  })

  # 3) Inject anti‑flash pair before </head> if not present
  if($html.IndexOf('NM_ANTI_FLASH_v13') -lt 0){
    $idx = $html.IndexOf('</head>',[System.StringComparison]::OrdinalIgnoreCase)
    if($idx -ge 0){
      $html = $html.Substring(0,$idx) + "`n" + $headInject + "`n" + $html.Substring($idx)
    } else {
      $html = $headInject + $html
    }
  }

  if($html -ne $orig){
    [System.IO.File]::WriteAllText($f.FullName,$html,(New-Object System.Text.UTF8Encoding($false)))
    $patched++
    Write-Host "patched: $($f.FullName)"
  }
}
Write-Host ("Done. Files patched: {0}" -f $patched)
