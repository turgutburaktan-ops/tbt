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
(async()=>{
 const app=(await api('/apps/'+appId)).data;
 if(app.attributes.bundleId!=='com.tbt.social')throw Error('Unexpected app');
 const versions=(await api('/apps/'+appId+'/appStoreVersions?filter[platform]=IOS&limit=20')).data;
 console.log('VERSIONS '+JSON.stringify(versions.map(v=>({id:v.id,...v.attributes}))));
 const builds=await api('/builds?filter[app]='+appId+'&sort=-uploadedDate&limit=10&include=preReleaseVersion');
 console.log('BUILDS '+JSON.stringify(builds.data.map(b=>({id:b.id,version:b.attributes.version,processingState:b.attributes.processingState,marketing:builds.included?.find(v=>v.id===b.relationships?.preReleaseVersion?.data?.id)?.attributes.version}))));
})().catch(e=>{console.error(e.message);process.exitCode=1;});