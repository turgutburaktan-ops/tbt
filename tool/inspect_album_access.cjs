const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
(async()=>{
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const project='en-iyi-cekim-noktasi';
 const info=(await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project})).data;
 const policy=(await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project+':getIamPolicy',method:'POST',data:{options:{requestedPolicyVersion:3}}})).data;
 const agent='serviceAccount:service-'+info.projectNumber+'@gcp-sa-firebasestorage.iam.gserviceaccount.com';
 const role='roles/firebaserules.firestoreServiceAgent';
 if (!(policy.bindings||[]).some(b=>b.role===role&&!b.condition&&(b.members||[]).includes(agent))) {
  if (!policy.etag) throw Error('Missing IAM concurrency token');
  if (!(policy.bindings||[]).some(b=>b.role==='roles/firebasestorage.serviceAgent'&&(b.members||[]).includes(agent))) throw Error('Expected Storage service agent not found');
  const binding=policy.bindings.find(b=>b.role===role&&!b.condition);
  if(binding) binding.members.push(agent); else policy.bindings.push({role,members:[agent]});
  await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project+':setIamPolicy',method:'POST',data:{policy,updateMask:'bindings,etag'}});
  console.log('Restored cross-service Firestore read role for Firebase Storage service agent');
 }
 const verified=(await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/'+project+':getIamPolicy',method:'POST',data:{options:{requestedPolicyVersion:3}}})).data;
 if (!(verified.bindings||[]).some(b=>b.role===role&&!b.condition&&(b.members||[]).includes(agent))) throw Error('Service role verification failed');
 console.log('PASS: Firebase Storage can evaluate Firestore participant rules; member-only album policy unchanged');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
