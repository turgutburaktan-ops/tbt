'use strict';
const crypto=require('node:crypto'),fs=require('node:fs');
const root='https://api.appstoreconnect.apple.com/v1';
const appId='6808182194',versionId='f1d47130-04d3-4d05-9d46-9963f14dab66';
const encode=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function token(){
 const now=Math.floor(Date.now()/1000);
 const unsigned=encode({alg:'ES256',kid:process.env.APP_STORE_CONNECT_API_KEY_ID,typ:'JWT'})+'.'+encode({iss:process.env.APP_STORE_CONNECT_API_ISSUER_ID,iat:now,exp:now+1000,aud:'appstoreconnect-v1'});
 return unsigned+'.'+crypto.sign('sha256',Buffer.from(unsigned),{key:process.env.APP_STORE_CONNECT_API_KEY,dsaEncoding:'ieee-p1363'}).toString('base64url');
}
async function api(path,method='GET',data){
 const r=await fetch(root+path,{method,headers:{Authorization:'Bearer '+token(),'Content-Type':'application/json'},...(data===undefined?{}:{body:JSON.stringify(data)}),signal:AbortSignal.timeout(60000)});
 const b=await r.json().catch(()=>({}));
 if(!r.ok)throw Error('App Store '+method+' '+path+' HTTP '+r.status+' '+JSON.stringify(b.errors?.map(e=>({code:e.code,detail:e.detail}))||[]));
 return b;
}
async function reviews(){
 const list=await api('/reviewSubmissions?filter[app]='+appId+'&limit=50');
 const out=[];
 for(const r of list.data){
  if(['COMPLETE','CANCELED'].includes(r.attributes.state))continue;
  const items=await api('/reviewSubmissions/'+r.id+'/items?include=appStoreVersion');
  out.push({...r,items:items.data});
 }
 return out;
}
async function current(){return (await api('/appStoreVersions/'+versionId)).data;}
(async()=>{
 const app=(await api('/apps/'+appId)).data;
 if(app.attributes.bundleId!=='com.tbt.social')throw Error('Unexpected app');
 let version=await current();
 if(version.attributes.versionString!=='1.0.18'||version.attributes.platform!=='IOS')throw Error('Unexpected version');
 let build;
 for(let attempt=0;attempt<40;attempt++){
  const list=await api('/builds?filter[app]='+appId+'&filter[version]=30&include=preReleaseVersion&limit=20');
  build=list.data.find(b=>list.included?.find(v=>v.id===b.relationships?.preReleaseVersion?.data?.id)?.attributes?.version==='1.0.18');
  if(build?.attributes.processingState==='VALID')break;
  if(build&&['FAILED','INVALID'].includes(build.attributes.processingState))throw Error('New build processing failed');
  console.log('Waiting for build 30 to finish processing, attempt '+(attempt+1));
  await sleep(30000);
 }
 if(!build||build.attributes.processingState!=='VALID'||build.attributes.expired)throw Error('Build 30 is not ready; current review left unchanged');
 console.log('Verified valid iOS 1.0.18 build 30: '+build.id);
 let attached=(await api('/appStoreVersions/'+versionId+'/build')).data;
 if(attached?.id===build.id&&['WAITING_FOR_REVIEW','IN_REVIEW','PENDING_DEVELOPER_RELEASE','READY_FOR_SALE'].includes(version.attributes.appStoreState)){
  console.log('IOS_UPDATE_ALREADY_SUBMITTED build=30 state='+version.attributes.appStoreState);return;
 }
 if(['READY_FOR_SALE','PENDING_DEVELOPER_RELEASE','PROCESSING_FOR_APP_STORE'].includes(version.attributes.appStoreState))throw Error('Previous version advanced; refusing to alter a released version');
 // Only replace the previous, single-item TBT update after the replacement is valid.
 if(['WAITING_FOR_REVIEW','IN_REVIEW'].includes(version.attributes.appStoreState)){
  const active=(await reviews()).filter(r=>r.items.some(i=>i.relationships?.appStoreVersion?.data?.id===versionId)&&['WAITING_FOR_REVIEW','IN_REVIEW'].includes(r.attributes.state));
  if(active.length!==1||active[0].items.length!==1)throw Error('Review contains unexpected items; leaving it unchanged');
  if(attached?.attributes?.version!=='29')throw Error('Pending review is not build 29; leaving it unchanged');
  await api('/reviewSubmissions/'+active[0].id,'PATCH',{data:{type:'reviewSubmissions',id:active[0].id,attributes:{canceled:true}}});
  console.log('Withdrew previous build 29 for replacement with verified build 30');
  for(let attempt=0;attempt<30;attempt++){
   version=await current();
   if(['PREPARE_FOR_SUBMISSION','DEVELOPER_REJECTED','REJECTED','METADATA_REJECTED','READY_FOR_REVIEW'].includes(version.attributes.appStoreState))break;
   await sleep(10000);
  }
 }
 version=await current();
 if(!['PREPARE_FOR_SUBMISSION','DEVELOPER_REJECTED','REJECTED','METADATA_REJECTED','READY_FOR_REVIEW'].includes(version.attributes.appStoreState))throw Error('Version is not editable: '+version.attributes.appStoreState);
 if(build.attributes.usesNonExemptEncryption==null){
  // The signed application's existing Info.plist declares this same value.
  await api('/builds/'+build.id,'PATCH',{data:{type:'builds',id:build.id,attributes:{usesNonExemptEncryption:false}}});
 }
 await api('/appStoreVersions/'+versionId+'/relationships/build','PATCH',{data:{type:'builds',id:build.id}});
 const localizations=(await api('/appStoreVersions/'+versionId+'/appStoreVersionLocalizations')).data;
 for(const l of localizations){
  const whatsNew=l.attributes.locale.startsWith('tr')
   ? 'Keşfet ve Reels geri getirildi. Gezilecek yerlerde şehir seçimi, arama ve sıralama düzeltildi. Seçilen yerler Akıllı Rota sonucunda düzenlenebiliyor. Profil fotoğrafının korunması, takip bağlantıları ve profil sekmeleri düzeltildi. Hata mesajları Türkçeleştirildi.'
   : 'Restored Discover and Reels. Improved city selection, place search and sorting. Selected stops now open in Smart Route results, where places and venues can be added. Fixed profile photo preservation, follower profile links and profile tabs. Improved error messages.';
  await api('/appStoreVersionLocalizations/'+l.id,'PATCH',{data:{type:'appStoreVersionLocalizations',id:l.id,attributes:{whatsNew}}});
 }
 let review=(await reviews()).find(r=>r.attributes.state==='READY_FOR_REVIEW'&&r.items.length===1&&r.items[0].relationships?.appStoreVersion?.data?.id===versionId);
 if(!review){
  review=(await api('/reviewSubmissions','POST',{data:{type:'reviewSubmissions',attributes:{platform:'IOS'},relationships:{app:{data:{type:'apps',id:appId}}}}})).data;
  await api('/reviewSubmissionItems','POST',{data:{type:'reviewSubmissionItems',relationships:{reviewSubmission:{data:{type:'reviewSubmissions',id:review.id}},appStoreVersion:{data:{type:'appStoreVersions',id:versionId}}}}});
 }
 await api('/reviewSubmissions/'+review.id,'PATCH',{data:{type:'reviewSubmissions',id:review.id,attributes:{submitted:true}}});
 const final=(await api('/reviewSubmissions/'+review.id)).data;
 attached=(await api('/appStoreVersions/'+versionId+'/build')).data;
 if(attached?.id!==build.id||!['WAITING_FOR_REVIEW','IN_REVIEW','COMPLETE'].includes(final.attributes.state))throw Error('Submission state not confirmed');
 console.log('IOS_UPDATE_SUBMITTED version=1.0.18 build=30 state='+final.attributes.state+' review='+review.id);
 if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'App Store: TBT 1.0.18 (30) submitted. State: '+final.attributes.state+'\n');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
