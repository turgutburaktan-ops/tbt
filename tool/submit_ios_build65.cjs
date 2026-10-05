'use strict';
require('node:child_process').execFileSync(process.execPath, [require('node:path').join(__dirname, 'security_release_gate.cjs'), '--release=65'], {stdio: 'inherit'});
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
 const r=await fetch(path.startsWith('https://api.appstoreconnect.apple.com/')?path:root+path,{method,headers:{Authorization:'Bearer '+token(),'Content-Type':'application/json'},...(data===undefined?{}:{body:JSON.stringify(data)}),signal:AbortSignal.timeout(60000)});
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
  const list=await api('/builds?filter[app]='+appId+'&filter[version]=65&include=preReleaseVersion&limit=20');
  build=list.data.find(b=>list.included?.find(v=>v.id===b.relationships?.preReleaseVersion?.data?.id)?.attributes?.version==='1.0.37');
  if(build?.attributes.processingState==='VALID')break;
  if(build&&['FAILED','INVALID'].includes(build.attributes.processingState))throw Error('Build 65 processing failed');
  console.log('Waiting for iOS 1.0.37 build 65 processing: '+(attempt+1));
  await sleep(30000);
 }
 if(!build||build.attributes.processingState!=='VALID'||build.attributes.expired)throw Error('Build 65 not ready; existing release left unchanged');
 console.log('VALIDATED_IOS_BUILD '+build.id);
 const versions=(await api('/apps/'+appId+'/appStoreVersions?filter[platform]=IOS&limit=50')).data;
 const newer=v=>v.attributes.versionString.split('.').map(Number).reduce((n,x)=>n*1000+x,0)>1000037;
 if(versions.some(newer))throw Error('A newer iOS version exists; refusing an older update');
 let version=versions.find(v=>v.attributes.versionString==='1.0.37');
 if(!version){
  const editable=versions.filter(v=>!['READY_FOR_SALE','READY_FOR_DISTRIBUTION','REMOVED_FROM_SALE','DEVELOPER_REMOVED_FROM_SALE','REPLACED_WITH_NEW_VERSION'].includes(v.attributes.appStoreState));
  if(editable.length)throw Error('Another iOS version is active; refusing to replace it');
  version=(await api('/appStoreVersions','POST',{data:{type:'appStoreVersions',attributes:{platform:'IOS',versionString:'1.0.37',releaseType:'AFTER_APPROVAL',copyright:'2026 TBT'},relationships:{app:{data:{type:'apps',id:appId}}}}})).data;
 }
 const versionId=version.id;
 const attached=(await api('/appStoreVersions/'+versionId+'/build')).data;
 if(attached?.id===build.id&&['WAITING_FOR_REVIEW','IN_REVIEW','PENDING_DEVELOPER_RELEASE','READY_FOR_SALE','READY_FOR_DISTRIBUTION'].includes(version.attributes.appStoreState)){
  console.log('IOS_UPDATE_ALREADY_SUBMITTED version=1.0.37 build=65 state='+version.attributes.appStoreState);return;
 }
 if(!['PREPARE_FOR_SUBMISSION','DEVELOPER_REJECTED','REJECTED','METADATA_REJECTED','READY_FOR_REVIEW'].includes(version.attributes.appStoreState))throw Error('Target version not editable: '+version.attributes.appStoreState);
 // The app implements standard encryption outside the OS. Do not claim OS-only encryption.
 const availability=(await api('/apps/'+appId+'/appAvailabilityV2')).data;
 if(availability.attributes.availableInNewTerritories)throw Error('Encryption distribution needs review: new territories automatically enabled');
 let territoryPath=availability.relationships.territoryAvailabilities.links.related+'?limit=200&include=territory',france;
 while(territoryPath){const page=await api(territoryPath);france=france||page.data.find(x=>x.relationships?.territory?.data?.id==='FRA');territoryPath=page.links?.next;}
 if(!france||france.attributes.available!==false)throw Error('French encryption documentation required before submission');
 // Apple requires documentation for standard third-party algorithms only for
 // France. France is unavailable above. The API itself rejects a declaration
 // for proprietary=false, thirdParty=true, France=false (409 ATTRIBUTE.INVALID).
 // This is a documentation exemption, not a claim that encryption is absent.
 // https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption
 // https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation
 await api('/builds/'+build.id,'PATCH',{data:{type:'builds',id:build.id,attributes:{usesNonExemptEncryption:false}}});
 const checked=(await api('/builds/'+build.id)).data;
 if(checked.attributes.usesNonExemptEncryption!==false)throw Error('Encryption documentation exemption readback mismatch');
 console.log('ENCRYPTION_DOCUMENTATION_EXEMPT: standard third-party algorithms; France unavailable; encryption remains enabled');
 await api('/appStoreVersions/'+versionId+'/relationships/build','PATCH',{data:{type:'builds',id:build.id}});
 const localizations=(await api('/appStoreVersions/'+versionId+'/appStoreVersionLocalizations')).data;
 if(!localizations.length)throw Error('New version has no inherited store metadata');
 for(const l of localizations){
  const whatsNew=l.attributes.locale.startsWith('tr')
   ? 'Rota oluşturma ekranları birleştirildi. Profil gönderilerinin yüklenmesi ve Admin düğmesinin yerleşimi düzeltildi. Video kalitesi korunarak Reels ön yüklemesi eklendi.'
   : 'Unified route creation, improved profile feed loading and fixed admin header overlap. Added original-quality Reels prefetching.';
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
 console.log('IOS_UPDATE_SUBMITTED version=1.0.37 build=65 state='+final.attributes.state+' review='+review.id+' versionId='+versionId);
 if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,'TBT iOS 1.0.37 (65) submitted: '+final.attributes.state+'\n');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
