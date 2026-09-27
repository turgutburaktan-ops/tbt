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
 let committed=false;
 try {
   const tracks=(await req(url+'/tracks')).tracks||[];
   if(tracks.some(t=>(t.releases||[]).some(r=>(r.versionCodes||[]).some(v=>Number(v)>59))))throw Error('Newer release exists; refusing to replace it');
   const alpha=tracks.find(t=>t.track==='alpha');
   const release=(alpha?.releases||[]).find(r=>(r.versionCodes||[]).includes('59'));
   if(!release||release.name!=='59 (1.0.31)'||release.versionCodes.length!==1)throw Error('Expected build59 alpha release not found');
   if(!['draft','completed'].includes(release.status))throw Error('Unexpected release state');
   if((alpha.releases||[]).some(r=>r!==release&&r.status!=='completed'))throw Error('Another active draft or staged release exists');
   const bundles=(await req(url+'/bundles')).bundles||[];
   if(bundles.some(b=>Number(b.versionCode)>59))throw Error('Newer bundle exists');
   if(!bundles.some(b=>Number(b.versionCode)===59&&b.sha256))throw Error('Verified build59 bundle missing');
   if(release.status==='completed'){
     console.log('PLAY_ALPHA_ALREADY_COMPLETED versionCode=59');
     return;
   }
   await req(url+'/tracks/alpha','PUT',{track:'alpha',releases:[{...release,status:'completed'}]});
   await req(url+':validate','POST');
   await req(url+':commit?changesInReviewBehavior=ERROR_IF_IN_REVIEW','POST');
   committed=true;
   const check=await req(base,'POST',{}),checkUrl=base+'/'+encodeURIComponent(check.id);
   try {
     const track=await req(checkUrl+'/tracks/alpha');
     if(!(track.releases||[]).some(r=>(r.versionCodes||[]).includes('59')&&r.status==='completed'))throw Error('Completed alpha release not confirmed');
     console.log('PLAY_ALPHA_READBACK '+JSON.stringify(track));
   } finally {await req(checkUrl,'DELETE');}
   console.log('PLAY_ALPHA_COMMITTED versionCode=59 status=completed review=SUBMITTED');
 } finally {if(!committed)await req(url,'DELETE');}
})().catch(e=>{console.error(e.message);if(e.apiMessage)console.error(e.apiMessage);process.exitCode=1;});
