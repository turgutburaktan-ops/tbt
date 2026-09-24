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
 const versions=(await api('/apps/'+appId+'/appStoreVersions?filter[platform]=IOS&limit=20')).data;
 const builds=await api('/builds?filter[app]='+appId+'&sort=-uploadedDate&limit=20&include=preReleaseVersion');
 console.log('APPLE_STATUS '+JSON.stringify({versions:versions.map(v=>({id:v.id,version:v.attributes.versionString,state:v.attributes.appStoreState})),builds:builds.data.map(b=>({id:b.id,build:b.attributes.version,state:b.attributes.processingState,version:builds.included?.find(v=>v.id===b.relationships?.preReleaseVersion?.data?.id)?.attributes?.version}))}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
