'use strict';
const crypto=require('node:crypto'),fs=require('node:fs');
const root='https://api.appstoreconnect.apple.com/v1';
const appId='6808182194';
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

(async()=>{
 const app=(await api('/apps/'+appId)).data;
 if(app.attributes.bundleId!=='com.tbt.social')throw Error('Unexpected app');
 let build;
 for(let attempt=0;attempt<60;attempt++){
  const list=await api('/builds?filter[app]='+appId+'&filter[version]=59&include=preReleaseVersion&limit=20');
  build=list.data.find(b=>list.included?.find(v=>v.id===b.relationships?.preReleaseVersion?.data?.id)?.attributes?.version==='1.0.31');
  if(build?.attributes.processingState==='VALID')break;
  if(build&&['FAILED','INVALID'].includes(build.attributes.processingState))throw Error('Build 59 processing failed');
  console.log('Waiting for iOS 1.0.31 build 59 processing: '+(attempt+1));
  await sleep(30000);
 }
 if(!build||build.attributes.processingState!=='VALID'||build.attributes.expired)throw Error('Build 59 not ready; existing release left unchanged');
 console.log('VALIDATED_IOS_BUILD '+build.id);
 const versions=(await api('/apps/'+appId+'/appStoreVersions?filter[platform]=IOS&limit=50')).data;
 const newer=v=>v.attributes.versionString.split('.').map(Number).reduce((n,x)=>n*1000+x,0)>1000031;
 if(versions.some(newer))throw Error('A newer iOS version exists; refusing an older update');
 let version=versions.find(v=>v.attributes.versionString==='1.0.31');
 if(!version){
  const editable=versions.filter(v=>!['READY_FOR_SALE','READY_FOR_DISTRIBUTION','REMOVED_FROM_SALE','DEVELOPER_REMOVED_FROM_SALE','REPLACED_WITH_NEW_VERSION'].includes(v.attributes.appStoreState));
  if(editable.length)throw Error('Another iOS version is active; refusing to replace it');
  version=(await api('/appStoreVersions','POST',{data:{type:'appStoreVersions',attributes:{platform:'IOS',versionString:'1.0.31',releaseType:'AFTER_APPROVAL',copyright:'2026 TBT'},relationships:{app:{data:{type:'apps',id:appId}}}}})).data;
 }
 const versionId=version.id;
 const attached=(await api('/appStoreVersions/'+versionId+'/build')).data;
 if(attached?.id===build.id&&['WAITING_FOR_REVIEW','IN_REVIEW','PENDING_DEVELOPER_RELEASE','READY_FOR_SALE','READY_FOR_DISTRIBUTION'].includes(version.attributes.appStoreState)){
  console.log('IOS_UPDATE_ALREADY_SUBMITTED version=1.0.31 build=59 state='+version.attributes.appStoreState);return;
 }
 if(!['PREPARE_FOR_SUBMISSION','DEVELOPER_REJECTED','REJECTED','METADATA_REJECTED','READY_FOR_REVIEW'].includes(version.attributes.appStoreState))throw Error('Target version not editable: '+version.attributes.appStoreState);
 if(build.attributes.usesNonExemptEncryption==null)await api('/builds/'+build.id,'PATCH',{data:{type:'builds',id:build.id,attributes:{usesNonExemptEncryption:false}}});
 await api('/appStoreVersions/'+versionId+'/relationships/build','PATCH',{data:{type:'builds',id:build.id}});
 const localizations=(await api('/appStoreVersions/'+versionId+'/appStoreVersionLocalizations')).data;
 if(!localizations.length)throw Error('New version has no inherited store metadata');
 for(const l of localizations){
  const whatsNew=l.attributes.locale.startsWith('tr')
   ? "Rota oluşturma ve harita deneyimi yenilendi. Yürüyüş ve bisiklet rotalarına yükselti ve tahmini zorluk bilgileri eklendi. Rota görünürlüğü, katılım ve onay seçenekleri ayrıldı. Rotaları Keşfet’te paylaşma, kaydetme ve kopyalama; rota duraklarını Gezi’ye önerme özellikleri eklendi."
   : "Updated route planning and maps. Added elevation and estimated difficulty for walking and cycling routes, separate visibility and participation settings, route discovery publishing, bookmarks and private copies, and moderated place suggestions from route stops.";
  await api('/appStoreVersionLocalizations/'+l.id,'PATCH',{data:{type:'appStoreVersionLocalizations',id:l.id,attributes:{whatsNew}}});
 }
 let review=(await reviews()).find(r=>r.attributes.state==='READY_FOR_REVIEW'&&r.items.length===1&&r.items[0].relationships?.appStoreVersion?.data?.id===versionId);
 if(!review){
  review=(await api('/reviewSubmissions','POST',{data:{type:'reviewSubmissions',attributes:{platform:'IOS'},relationships:{app:{data:{type:'apps',id:appId}}}}})).data;
  await api('/reviewSubmissionItems','POST',{data:{type:'reviewSubmissionItems',relationships:{reviewSubmission:{data:{type:'reviewSubmissions',id:review.id}},appStoreVersion:{data:{type:'appStoreVersions',id:versionId}}}}});
 }
 await api('/reviewSubmissions/'+review.id,'PATCH',{data:{type:'reviewSubmissions',id:review.id,attributes:{submitted:true}}});
 const final=(await api('/reviewSubmissions/'+review.id)).data;
 const finalBuild=(await api('/appStoreVersions/'+versionId+'/build')).data;
 if(finalBuild?.id!==build.id||!['WAITING_FOR_REVIEW','IN_REVIEW','COMPLETE'].includes(final.attributes.state))throw Error('Submission state not confirmed');
 console.log('IOS_UPDATE_SUBMITTED version=1.0.31 build=59 state='+final.attributes.state+' review='+review.id+' versionId='+versionId);
 if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'TBT iOS 1.0.31 (59) submitted: '+final.attributes.state+'\n');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
