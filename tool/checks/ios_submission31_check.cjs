'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),crypto=require('node:crypto');
const source=fs.readFileSync('tool/submit_ios_build31.cjs','utf8');
const key=crypto.generateKeyPairSync('ec',{namedCurve:'prime256v1'}).privateKey.export({type:'pkcs8',format:'pem'});
const versionId='f1d47130-04d3-4d05-9d46-9963f14dab66';
async function scenario({invalid=false,extraItem=false,released=false}={}){
 let state=released?'READY_FOR_SALE':'WAITING_FOR_REVIEW',attached='old-build',reviewState='WAITING_FOR_REVIEW';
 const mutations=[],logs=[],env={APP_STORE_CONNECT_API_KEY_ID:'test',APP_STORE_CONNECT_API_ISSUER_ID:'test',APP_STORE_CONNECT_API_KEY:key};
 const proc={env,exitCode:0};
 const fetch=async(url,options)=>{
  const path=url.replace('https://api.appstoreconnect.apple.com/v1',''),method=options.method;
  const data=options.body?JSON.parse(options.body).data:null;
  if(method!=='GET')mutations.push({path,method,data});
  let body;
  if(path==='/apps/6808182194')body={data:{attributes:{bundleId:'com.tbt.social'}}};
  else if(path==='/appStoreVersions/'+versionId)body={data:{id:versionId,attributes:{versionString:'1.0.18',platform:'IOS',appStoreState:state}}};
  else if(path.startsWith('/builds?'))body={data:[{id:'new-build',attributes:{version:'31',processingState:invalid?'INVALID':'VALID',usesNonExemptEncryption:false},relationships:{preReleaseVersion:{data:{id:'train'}}}}],included:[{id:'train',attributes:{version:'1.0.18'}}]};
  else if(path==='/appStoreVersions/'+versionId+'/build')body={data:{id:attached,attributes:{version:attached==='old-build'?'30':'31'}}};
  else if(path.startsWith('/reviewSubmissions?'))body={data:reviewState==='COMPLETE'?[]:[{id:'review',attributes:{state:reviewState}}]};
  else if(path==='/reviewSubmissions/review/items?include=appStoreVersion')body={data:[{id:'item',relationships:{appStoreVersion:{data:{id:versionId}}}},...(extraItem?[{id:'other'}]:[])]};
  else if(path==='/reviewSubmissions/review'&&method==='PATCH'){
   if(data.attributes.canceled){state='DEVELOPER_REJECTED';reviewState='COMPLETE';}
   else{state='WAITING_FOR_REVIEW';reviewState='WAITING_FOR_REVIEW';}
   body={data:{id:'review',attributes:{state:reviewState}}};
  }
  else if(path==='/appStoreVersions/'+versionId+'/relationships/build'){attached=data.id;body={};}
  else if(path==='/appStoreVersions/'+versionId+'/appStoreVersionLocalizations')body={data:[{id:'tr',attributes:{locale:'tr'}}]};
  else if(path==='/appStoreVersionLocalizations/tr')body={data:{id:'tr'}};
  else if(path==='/reviewSubmissions'&&method==='POST'){reviewState='READY_FOR_REVIEW';body={data:{id:'review'}};}
  else if(path==='/reviewSubmissionItems')body={data:{id:'item'}};
  else if(path==='/reviewSubmissions/review')body={data:{id:'review',attributes:{state:reviewState}}};
  else throw Error('Unexpected path '+method+' '+path);
  return {ok:true,status:200,json:async()=>body};
 };
 await vm.runInNewContext(source,{require,Buffer,process:proc,console:{log:m=>logs.push(m),error:m=>logs.push(m)},fetch,setTimeout,AbortSignal});
 return {mutations,logs,exitCode:proc.exitCode};
}
(async()=>{
 for(const options of [{invalid:true},{extraItem:true},{released:true}]){
  const r=await scenario(options);assert.equal(r.exitCode,1);assert.equal(r.mutations.length,0);
 }
 const r=await scenario();assert.equal(r.exitCode,0,r.logs.join('\n'));
 assert.equal(r.mutations[0].data.attributes.canceled,true);
 assert.equal(r.mutations[1].data.id,'new-build');
 assert.equal(r.mutations.at(-1).data.attributes.submitted,true);
 assert(r.logs.some(l=>l.includes('IOS_UPDATE_SUBMITTED')));
 console.log('4 App Store submission scenarios passed.');
})().catch(e=>{console.error(e);process.exitCode=1;});
