# fix-and-patch-ONECLICK-FLASHGUARD-v6e.ps1
param([switch]$MakeBackup = $false)
$ErrorActionPreference = 'Stop'
$markerStart = '<!-- NM_FLASHGUARD_START -->'
$markerEnd   = '<!-- NM_FLASHGUARD_END -->'

$css = @'
<style id="nm-flashguard-css">
/* NM FlashGuard v6e — mask header briefly to kill flicker */
html.nm-preload a.skip-link { position:absolute !important; left:-9999px !important; }
html.nm-preload body > header,
html.nm-preload .ct-header,
html.nm-preload header.site-header { opacity:0; visibility:hidden; }

/* Avoid bullet/nav jank even if header becomes visible early */
html.nm-preload .ct-header .menu, html.nm-preload .ct-header .menu * { list-style:none !important; padding-left:0 !important; }
html.nm-preload .header-logo img:not(:first-child) { display:none !important; }
</style>
'@

$js = @'
<script id="nm-flashguard-js">
(function(){
  try{
    var d=document, html=d.documentElement, revealed=false;
    if(!html.classList.contains('nm-preload')) html.classList.add('nm-preload');
    function reveal(){ if(revealed) return; revealed=true; try{ html.classList.remove('nm-preload'); }catch(e){} }
    // Prefer full load; cap at 600ms to keep LCP stable
    window.addEventListener('load', reveal, {once:true});
    setTimeout(reveal, 600);
  }catch(e){}
})();
</script>
'@

$injection = "`n$markerStart`n$css`n$js`n$markerEnd`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$files = Get-ChildItem -Path $root -Recurse -Include *.html, *.htm -File
if($files.Count -eq 0){ Write-Host "No HTML files found."; exit 0 }

$backupDir = Join-Path $root "_flashguard_bak"
if($MakeBackup){ if(-not(Test-Path $backupDir)){ New-Item -ItemType Directory -Path $backupDir | Out-Null } }

$fresh=0; $replaced=0
foreach($f in $files){
  $content = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
  if($MakeBackup){
    $rel=$f.FullName.Substring($root.Length).TrimStart('\','/')
    $dest=Join-Path $backupDir $rel
    $dir=Split-Path -Parent $dest
    if(-not(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir | Out-Null }
    Copy-Item -Path $f.FullName -Destination $dest -Force
  }
  $start=$content.IndexOf($markerStart)
  if($start -ge 0){
    $end=$content.IndexOf($markerEnd,$start)
    if($end -ge 0){ $after=$end+$markerEnd.Length; $new=$content.Substring(0,$start)+$injection+$content.Substring($after) }
    else{ $new=$injection+$content }
    [System.IO.File]::WriteAllText($f.FullName,$new,$utf8NoBom)
    $replaced++
  } else {
    $idxHead=$content.IndexOf('</head>',[System.StringComparison]::OrdinalIgnoreCase)
    if($idxHead -ge 0){ $new=$content.Substring(0,$idxHead)+$injection+$content.Substring($idxHead) } else { $new=$injection+$content }
    [System.IO.File]::WriteAllText($f.FullName,$new,$utf8NoBom)
    $fresh++
  }
}
Write-Host ("NM FlashGuard v6e fresh: {0}, replaced: {1}" -f $fresh, $replaced) -ForegroundColor Green
Write-Host "Done."
