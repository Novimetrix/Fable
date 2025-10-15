/* NM Firebase loader (static-safe path) */
(function(){
  if (!window.nmFirebaseReady) { var r; window.nmFirebaseReady=new Promise(function(x){r=x}); window.__nmResolveFirebaseReady=r; }
  function cleanPath(p){try{if(!p){var ln=document.querySelector('link[rel="canonical"]'); if(ln&&ln.href)p=new URL(ln.href,location.origin).pathname;}}catch(e){} p=(p||location.pathname||'/').replace(/\/index\.html?$/i,'/'); if(p.charAt(0)!=='/')p='/'+p; return p;}
  (function(){var m=window.NM_THREAD||{}; var id=m.postId?('post:'+m.postId):('path:'+cleanPath(m.canonicalPath)); window.nmComments=Object.freeze({getThreadId:function(){return id;}})})();
  if (window.firebase || document.querySelector('script[src^="https://www.gstatic.com/firebasejs/"]')) { window.__nmResolveFirebaseReady&&window.__nmResolveFirebaseReady(); return; }
  var ORIGIN=['https','://','www.','gstatic','.com','/firebasejs/','9.22.1','/'].join('');
  if (window.__nmFirebaseLoading) return; window.__nmFirebaseLoading=true; var mods=["firebase-app-compat.js","firebase-auth-compat.js","firebase-firestore-compat.js"];
  function addScript(n){var s=document.createElement('script'); s.defer=true; s.setAttribute('data-nm-firebase','1'); s.src=ORIGIN+n; document.head.appendChild(s); return new Promise(function(res,rej){s.onload=res; s.onerror=function(){ rej(new Error('Failed to load '+s.src)); };});}
  var p=Promise.resolve(); mods.forEach(function(m){ p=p.then(function(){ return addScript(m); }); });
  p.then(function(){ window.__nmResolveFirebaseReady&&window.__nmResolveFirebaseReady();}).catch(function(err){ console.error('[NM Firebase Loader]', err); });
})();
