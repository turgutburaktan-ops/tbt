const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
(async()=>{
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const project='en-iyi-cekim-noktasi';
 const info=(await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project})).data;
 const policy=(await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project+':getIamPolicy',method:'POST',data:{}})).data;
 const agent='serviceAccount:service-'+info.projectNumber+'@gcp-sa-firebasestorage.iam.gserviceaccount.com';
 console.log('Storage service agent roles:',(policy.bindings||[]).filter(b=>(b.members||[]).includes(agent)).map(b=>b.role));
 console.log('Cross-service Firestore read role:',(policy.bindings||[]).some(b=>b.role==='roles/firebaserules.firestoreServiceAgent'&&(b.members||[]).includes(agent)));
 const fs=require('node:fs');const s=fs.readFileSync('storage.rules','utf8');const a=s.indexOf('match /route_albums/');console.log('Live album policy:',s.slice(a,s.indexOf('match /',a+7)));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
