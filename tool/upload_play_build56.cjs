'use strict';
const fs=require('node:fs'),crypto=require('node:crypto');
const base='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.tbt.social/edits';
(async()=>{
 const bytes=fs.readFileSync('build/app/outputs/bundle/release/app-release.aab');
 const info=fs.readFileSync('build/app/outputs/bundle/release/release-info.txt','utf8');
 const sha=crypto.createHash('sha256').update(bytes).digest('hex');
 if(!info.includes('applicationId=com.tbt.social')||!info.includes('versionCode=56')||!info.includes('versionName=1.0.28')||!info.includes(sha))throw Error('Artifact identity mismatch');
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
   const tracks=await req(url+'/tracks');
   if((tracks.tracks||[]).some(t=>(t.releases||[]).some(r=>(r.versionCodes||[]).some(v=>Number(v)>56))))throw Error('A newer Play release exists; refusing to replace it');
   const bundles=await req(url+'/bundles');
   if(!(bundles.bundles||[]).some(b=>Number(b.versionCode)===56)){
     const upload=await fetch('https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/com.tbt.social/edits/'+encodeURIComponent(edit.id)+'/bundles?uploadType=media',{method:'POST',headers:{Authorization:headers.Authorization,'Content-Type':'application/octet-stream'},body:bytes,signal:AbortSignal.timeout(300000)});
     const bundle=await upload.json();
     if(!upload.ok||Number(bundle.versionCode)!==56)throw Error('Bundle upload failed HTTP '+upload.status);
     if(bundle.sha256&&bundle.sha256.toLowerCase()!==sha)throw Error('Uploaded bundle checksum mismatch');
     console.log('Uploaded and verified versionCode 56');
   } else {
     const existing=(bundles.bundles||[]).find(b=>Number(b.versionCode)===56);
     if(!existing.sha256||existing.sha256.toLowerCase()!==sha)throw Error('Existing versionCode 56 has a different bundle; refusing reuse');
     console.log('VersionCode 56 already uploaded; checksum verified');
   }
   await req(url+'/tracks/alpha','PUT',{track:'alpha',releases:[{name:'56 (1.0.28)',versionCodes:['56'],status:'completed',releaseNotes:[{language:'tr-TR',text:"Kamera düğmesi TBT renkleriyle yenilendi. Story araçları sadeleştirildi; etkinlik, rota ve profil ekranları düzenlendi. Fotoğraf kadrajı, paylaşım bağlantıları, arama, mekân haritası ve QR davet görünümü iyileştirildi."}]}]});
   await req(url+':validate','POST');
   let review='SUBMITTED';
   try {await req(url+':commit?changesInReviewBehavior=ERROR_IF_IN_REVIEW','POST');}
   catch(e){
     if(!/changesNotSentForReview/.test(e.apiMessage||''))throw e;
     await req(url+':commit?changesNotSentForReview=true&changesInReviewBehavior=ERROR_IF_IN_REVIEW','POST');
     review='CONSOLE_SUBMISSION_REQUIRED';
   }
   committed=true;
   const check=await req(base,'POST',{}),checkUrl=base+'/'+encodeURIComponent(check.id);
   try {
     const track=await req(checkUrl+'/tracks/alpha');
     if(!(track.releases||[]).some(r=>(r.versionCodes||[]).includes('56')))throw Error('Committed alpha release could not be read back');
     console.log('PLAY_ALPHA_READBACK '+JSON.stringify(track));
   } finally {await fetch(checkUrl,{method:'DELETE',headers});}
   console.log('PLAY_RELEASE_COMMITTED alpha versionCode=56 review='+review);
   fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'Google Play Alpha: 1.0.28 (56) uploaded and committed. Review: '+review+'\nSHA256: '+sha+'\n');
 } finally {if(!committed){await fetch(url,{method:'DELETE',headers});console.log('Uncommitted edit discarded');}}
})().catch(e=>{console.error(e.message);if(/review/i.test(e.apiMessage||''))console.error('Review action required in Play Console');process.exitCode=1;});
