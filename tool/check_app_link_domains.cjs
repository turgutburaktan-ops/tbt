const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
(async()=>{
 const credentials=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
 if(credentials.project_id!=='en-iyi-cekim-noktasi')throw Error('Unexpected project');
 const auth=new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/cloud-platform']});
 const client=await auth.getClient();
 const response=await client.request({url:'https://firebase.googleapis.com/v1beta1/projects/en-iyi-cekim-noktasi/androidApps/1:330568532415:android:bf2ffa0b4d9210ed41a10a/sha'});
 console.log('REGISTERED_APP_CERTIFICATES', JSON.stringify(response.data));
 const playAuth=new GoogleAuth({credentials,scopes:['https://www.googleapis.com/auth/androidpublisher']});
 const play=await playAuth.getClient();
 const apks=await play.request({url:'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.tbt.social/generatedApks/30'});
 console.log('PLAY_SIGNING_SHA256',JSON.stringify(apks.data.generatedApks.map(x=>x.certificateSha256Hash)));

 for(const host of ['trtbt.com','www.trtbt.com']){
  for(const path of ['/.well-known/assetlinks.json','/.well-known/apple-app-site-association']){
   const r=await fetch('https://'+host+path,{redirect:'manual'});
   const body=await r.text();
   console.log('DOMAIN_ASSOCIATION',JSON.stringify({host,path,status:r.status,redirect:r.headers.get('location'),type:r.headers.get('content-type'),body:body.slice(0,2000)}));
  }
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
