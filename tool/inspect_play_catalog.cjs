'use strict';
const crypto=require('node:crypto');
const base='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.tbt.social/edits';
(async()=>{
 const sa=JSON.parse(process.env.PLAY_CREDENTIAL);
 if(sa.project_id!=='en-iyi-cekim-noktasi')throw Error('Unexpected project');
 const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url'),now=Math.floor(Date.now()/1000);
 const jwt=enc({alg:'RS256',typ:'JWT'})+'.'+enc({iss:sa.client_email,scope:'https://www.googleapis.com/auth/androidpublisher',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+1800});
 const assertion=jwt+'.'+crypto.sign('RSA-SHA256',Buffer.from(jwt),sa.private_key).toString('base64url');
 const auth=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})});
 const token=await auth.json();if(!auth.ok||!token.access_token)throw Error('Google authentication failed');
 const headers={Authorization:'Bearer '+token.access_token,'Content-Type':'application/json'};
 async function req(url,method='GET',data){
   const r=await fetch(url,{method,headers,...(data!==undefined?{body:JSON.stringify(data)}:{}),signal:AbortSignal.timeout(120000)});
   const b=await r.json().catch(()=>({}));
   if(!r.ok){const e=Error('Play API HTTP '+r.status+' '+(b.error?.status||''));e.apiMessage=b.error?.message||'';throw e;}return b;
 }

 const edit=await req(base,'POST',{}),url=base+'/'+encodeURIComponent(edit.id);
 try {console.log(JSON.stringify({tracks:await req(url+'/tracks'),bundles:await req(url+'/bundles')}));}
 finally {await fetch(url,{method:'DELETE',headers});}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
