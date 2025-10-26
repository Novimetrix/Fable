# EM-LOCK-DIAG-v2.ps1 — inject robust diagnostic panel (waits for DOM ready)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSCommandPath
if (-not (Test-Path $Root)) { Write-Host "Folder not found: $Root" -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }

Write-Host "Scanning (HTML only): $Root" -ForegroundColor Cyan
$files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in @('.html','.htm') } | Sort-Object FullName
$tot = $files.Count
Write-Host ("Found {0} HTML files" -f $tot)

$js = @'
(function(){
  function run(){
    try{
      var doc = document, de = doc.documentElement, b = doc.body;
      if(!b){ setTimeout(run, 100); return; } // wait for body
      function gs(el){ return window.getComputedStyle(el||de); }
      function q(sel){ return doc.querySelector(sel); }

      var entry = q(''.entry-content, .wp-block-post-content, .article-content, .post-content, .page-content'');
      var firstP = entry ? entry.querySelector(''p'') : q(''main p, article p, p'');

      var htmlFS = gs(de).fontSize;
      var bodyFS = gs(b).fontSize;
      var entryFS = entry ? gs(entry).fontSize : ''n/a'';
      var pFS = firstP ? gs(firstP).fontSize : ''n/a'';

      var vp = !!q(''meta[name="viewport"]'');
      var emLock = !!q(''style#em-mobile-size-lock'');

      var box = doc.createElement(''div'');
      box.id = ''em-lock-diag'';
      box.setAttribute(''style'',
        ''position:fixed;z-index:2147483647;right:10px;bottom:10px;background:#111;color:#0f0;font:12px/1.3 system-ui,Segoe UI,Arial,sans-serif;padding:10px 12px;border:1px solid #333;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,.4)'');
      box.innerHTML =
        ''<div style="color:#fff;margin-bottom:6px"><b>EM-LOCK Diag</b></div>''+
        ''<div>html: <b>''+htmlFS+''</b></div>''+
        ''<div>body: <b>''+bodyFS+''</b></div>''+
        ''<div>.entry-content: <b>''+entryFS+''</b></div>''+
        ''<div>first paragraph: <b>''+pFS+''</b></div>''+
        ''<div style="margin-top:6px;color:''+(vp?''#9f9'':''#f99'')+''">viewport meta: <b>''+(vp?''yes'':''no'')+''</b></div>''+
        ''<div style="color:''+(emLock?''#9f9'':''#f99'')+''">em-lock style: <b>''+(emLock?''present'':''missing'')+''</b></div>''+
        ''<button id="em-lock-diag-close" style="margin-top:8px;background:#222;color:#fff;border:1px solid #444;border-radius:6px;padding:4px 8px;cursor:pointer">Close</button>'';
      b.appendChild(box);
      var btn = doc.getElementById(''em-lock-diag-close'');
      if(btn){ btn.onclick=function(){ box.remove(); }; }
    }catch(e){ setTimeout(run, 200); }
  }
  if(document.readyState === ''loading''){ document.addEventListener(''DOMContentLoaded'', run); }
  else { run(); }
})();
'@
$scriptStart = '<script id="em-lock-diag">'
$scriptTag   = $scriptStart + $js + '</script>'

$changed=0; $replaced=0; $inserted=0; $i=0
foreach($f in $files){
  $i++; Write-Host ("[{0}/{1}] {2}" -f $i,$tot,$f.FullName)
  try{
    $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8

    $idx = $txt.IndexOf($scriptStart, [StringComparison]::OrdinalIgnoreCase)
    if ($idx -ge 0){
      $end = $txt.IndexOf('</script>', $idx)
      if ($end -gt $idx){ $end += 9; $txt = $txt.Substring(0,$idx) + $scriptTag + $txt.Substring($end); $replaced++ }
      else { $txt = $scriptTag + "`r`n" + $txt; $inserted++ }
    } else {
      # Prefer to insert before </body> so body exists when script runs
      $endBody = $txt.LastIndexOf('</body>', [StringComparison]::OrdinalIgnoreCase)
      if ($endBody -ge 0){
        $txt = $txt.Substring(0,$endBody) + "`r`n"+$scriptTag+"`r`n" + $txt.Substring($endBody)
        $inserted++
      } else {
        # Fallback to after <head>
        $ci = [System.Globalization.CultureInfo]::InvariantCulture
        $headIdx = $ci.CompareInfo.IndexOf($txt, '<head', [System.Globalization.CompareOptions]::IgnoreCase)
        if ($headIdx -ge 0){
          $gt = $txt.IndexOf('>', $headIdx)
          if ($gt -ge 0){ $txt = $txt.Insert($gt+1, "`r`n"+$scriptTag+"`r`n"); $inserted++ }
          else { $txt = $scriptTag + "`r`n" + $txt; $inserted++ }
        } else { $txt = $scriptTag + "`r`n" + $txt; $inserted++ }
      }
    }

    Set-Content -LiteralPath $f.FullName -Value $txt -Encoding UTF8
    $changed++
  } catch {
    Write-Host ("  Error: {0} -> {1}" -f $f.FullName, $_) -ForegroundColor Red
  }
}

Write-Host ("Done. Files changed: {0}. scripts replaced: {1}, inserted: {2}" -f $changed,$replaced,$inserted) -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to close"
exit
