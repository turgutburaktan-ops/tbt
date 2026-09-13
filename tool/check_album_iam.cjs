const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
(async()=>{
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const project='en-iyi-cekim-noktasi';
 const info=(await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project})).data;
 const policy=(await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project+':getIamPolicy',method:'POST',data:{options:{requestedPolicyVersion:3}}})).data;
 const email='service-'+info.projectNumber+'@gcp-sa-firebasestorage.iam.gserviceaccount.com';
 const role='roles/firebaserules.firestoreServiceAgent';
 const present=(policy.bindings||[]).some(b=>b.role===role&&!b.condition&&(b.members||[]).includes('serviceAccount:'+email));
 console.log(JSON.stringify({project,serviceAgent:email,requiredRole:role,present}));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
