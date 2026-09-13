'use strict';
const crypto = require('node:crypto');
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
async function request(url, token, method='GET', data) {
 const response = await fetch(url, {method, headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'}, ...(data === undefined ? {} : {body:JSON.stringify(data)}), signal:AbortSignal.timeout(60000)});
 const body=await response.json().catch(()=>({}));
 if(!response.ok) throw Error('Store API HTTP '+response.status+' '+(body.errors?.[0]?.code||body.error?.status||''));
 return body;
}
(async()=>{
 const now=Math.floor(Date.now()/1000);
 const appleHeader=encode({alg:'ES256',kid:process.env.APP_STORE_CONNECT_API_KEY_ID,typ:'JWT'});
 const applePayload=encode({iss:process.env.APP_STORE_CONNECT_API_ISSUER_ID,iat:now,exp:now+1000,aud:'appstoreconnect-v1'});
 const appleUnsigned=appleHeader+'.'+applePayload;
 const appleToken=appleUnsigned+'.'+crypto.sign('sha256',Buffer.from(appleUnsigned),{key:process.env.APP_STORE_CONNECT_API_KEY,dsaEncoding:'ieee-p1363'}).toString('base64url');
 const root='https://api.appstoreconnect.apple.com/v1';
 const apps=await request(root+'/apps?filter[bundleId]=com.tbt.social',appleToken);
 if(apps.data?.length!==1)throw Error('Expected exactly one TBT app');
 const app=apps.data[0];
 const versions=await request(root+'/apps/'+app.id+'/appStoreVersions?filter[platform]=IOS&limit=20',appleToken);
 const builds=await request(root+'/builds?filter[app]='+app.id+'&sort=-uploadedDate&limit=15&include=preReleaseVersion',appleToken);
 console.log('APPLE_APP',JSON.stringify({id:app.id,name:app.attributes.name}));
 console.log('APPLE_VERSIONS',JSON.stringify(versions.data.map(x=>({id:x.id,version:x.attributes.versionString,state:x.attributes.appStoreState}))));
 console.log('APPLE_BUILDS',JSON.stringify(builds.data.map(x=>({id:x.id,build:x.attributes.version,state:x.attributes.processingState,version:builds.included?.find(p=>p.id===x.relationships?.preReleaseVersion?.data?.id)?.attributes?.version}))));
 const sa=JSON.parse(process.env.PLAY_CREDENTIAL);
 if(sa.project_id!=='en-iyi-cekim-noktasi')throw Error('Unexpected Google project');
 const unsigned=encode({alg:'RS256',typ:'JWT'})+'.'+encode({iss:sa.client_email,scope:'https://www.googleapis.com/auth/androidpublisher',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+1800});
 const assertion=unsigned+'.'+crypto.sign('RSA-SHA256',Buffer.from(unsigned),sa.private_key).toString('base64url');
 const auth=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})});
 const token=await auth.json();if(!auth.ok||!token.access_token)throw Error('Google authentication failed');
 const base='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.tbt.social/edits';
 const edit=await request(base,token.access_token,'POST',{});
 try{
 const tracks=await request(base+'/'+edit.id+'/tracks',token.access_token);
 console.log('PLAY_TRACKS',JSON.stringify(tracks.tracks.map(t=>({track:t.track,releases:t.releases?.map(r=>({name:r.name,codes:r.versionCodes,status:r.status}))}))));
 const bundles=await request(base+'/'+edit.id+'/bundles',token.access_token);
 console.log('PLAY_BUNDLES',JSON.stringify(bundles.bundles?.map(b=>b.versionCode)||[]));
 }finally{await request(base+'/'+edit.id,token.access_token,'DELETE');}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
