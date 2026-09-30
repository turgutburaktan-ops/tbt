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
 for(const path of ['/apps/'+appId+'/appEncryptionDeclarations?limit=100','/apps/'+appId+'/appAvailabilityV2','/apps/'+appId+'/appStoreVersions?filter[platform]=IOS&limit=20']){
  try{const r=await api(path);console.log('APPLE_INSPECT '+JSON.stringify({path,data:r.data}));
   if(path.endsWith('/appAvailabilityV2')){
    let p='/appAvailabilities/'+r.data.id+'/territoryAvailabilities?limit=200&include=territory';
    while(p){const t=await api(p);console.log('TERRITORIES '+JSON.stringify(t.data.map(x=>({attributes:x.attributes,territory:x.relationships?.territory?.data?.id}))));p=t.links?.next?t.links.next.replace(root,''):null;}
   }
  }catch(e){console.log(e.message);}
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
