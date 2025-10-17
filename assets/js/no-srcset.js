(function(){
  if(window.__noSrcsetActive)return; window.__noSrcsetActive=true;
  function strip(el){ if(!el)return; el.removeAttribute("srcset"); el.removeAttribute("imagesrcset"); el.removeAttribute("sizes"); }
  function sweep(root){ (root.querySelectorAll?root:document).querySelectorAll("img,source,link").forEach(strip); }
  sweep(document);
  var mo=new MutationObserver(function(ms){ ms.forEach(function(m){
    if(m.type==="childList"){ m.addedNodes.forEach(function(n){ if(n.nodeType===1) sweep(n); }); }
    else if(m.type==="attributes"){ strip(m.target); }
  });});
  mo.observe(document.documentElement,{childList:true,subtree:true,attributes:true,attributeFilter:["srcset","imagesrcset","sizes"]});
})();