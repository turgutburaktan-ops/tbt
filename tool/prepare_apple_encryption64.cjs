'use strict';
require('node:child_process').execFileSync(process.execPath, [require('node:path').join(__dirname, 'security_release_gate.cjs'), '--release=64'], {stdio: 'inherit'});
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
 // The app implements standard encryption outside the OS. Do not claim OS-only encryption.
 const availability=(await api('/apps/'+appId+'/appAvailabilityV2')).data;
 if(availability.attributes.availableInNewTerritories)throw Error('Encryption distribution needs review: new territories automatically enabled');
 let territoryPath=availability.relationships.territoryAvailabilities.links.related+'?limit=200&include=territory',france;
 while(territoryPath){const page=await api(territoryPath);france=france||page.data.find(x=>x.relationships?.territory?.data?.id==='FRA');territoryPath=page.links?.next;}
 if(!france||france.attributes.available!==false)throw Error('French encryption documentation required before submission');
 const description='TBT 1.0.36 uses Signal protocol messaging via libsignal_protocol_dart and AES-GCM media encryption. It uses standard cryptographic algorithms implemented outside the Apple operating system. No proprietary cryptographic algorithm is implemented. Distribution in France is disabled.';
 const declarations=(await api('/appEncryptionDeclarations?filter[app]='+appId+'&limit=100')).data;
 let declaration=declarations.find(x=>x.attributes.appDescription===description&&x.attributes.usesEncryption===true&&x.attributes.containsThirdPartyCryptography===true&&x.attributes.containsProprietaryCryptography===false&&x.attributes.availableOnFrenchStore===false);
 if(!declaration)declaration=(await api('/appEncryptionDeclarations','POST',{data:{type:'appEncryptionDeclarations',attributes:{appDescription:description,usesEncryption:true,exempt:false,containsProprietaryCryptography:false,containsThirdPartyCryptography:true,availableOnFrenchStore:false},relationships:{app:{data:{type:'apps',id:appId}}}}})).data;
 console.log('ENCRYPTION_DECLARATION '+declaration.id+' state='+declaration.attributes.appEncryptionDeclarationState);

})().catch(e=>{console.error(e.message);process.exitCode=1;});
