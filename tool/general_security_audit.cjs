const fs=require('node:fs');
const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
const {Storage}=require('../functions/node_modules/@google-cloud/storage');
(async()=>{
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const project='en-iyi-cekim-noktasi',number='330568532415',bucketName=project+'.firebasestorage.app';
 const get=async url=>(await client.request({url})).data;
 const report={at:new Date().toISOString(),mode:'READ_ONLY_PRODUCTION'};
 for(const [name,release] of [['firestore','cloud.firestore'],['storage','firebase.storage/'+bucketName]]){
  const base='https://firebaserules.googleapis.com/v1/';
  const r=await get(base+'projects/'+project+'/releases/'+release);
  const source=await get(base+r.rulesetName);
  if(source.source.files.length!==1)throw Error('Unexpected rule source layout');
  fs.writeFileSync(name+'.rules',source.source.files[0].content);report[name+'Ruleset']=r.rulesetName;
 }
 async function optional(name,url,pick){try{report[name]=pick(await get(url));}catch(e){report[name]={unverified:true,status:e.response?.status||e.code};}}
 await optional('authentication','https://identitytoolkit.googleapis.com/admin/v2/projects/'+project+'/config',d=>({passwordPolicy:d.passwordPolicyConfig||null,mfa:d.mfa?.state||null,emailPasswordEnabled:d.signIn?.email?.enabled}));
 await optional('appCheck','https://firebaseappcheck.googleapis.com/v1/projects/'+number+'/services',d=>(d.services||[]).map(s=>({name:s.name,enforcementMode:s.enforcementMode})));
 await optional('database','https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)',d=>({locationId:d.locationId,pointInTimeRecoveryEnablement:d.pointInTimeRecoveryEnablement,deleteProtectionState:d.deleteProtectionState}));
 try {
  const [m]=await new Storage().bucket(bucketName).getMetadata();
  report.bucket={location:m.location,iamConfiguration:m.iamConfiguration,softDeletePolicy:m.softDeletePolicy,versioning:m.versioning};
 }catch(e){report.bucket={unverified:true,status:e.code};}
 report.mediaInventory={};
 const bucket=new Storage().bucket(bucketName);
 for(const prefix of ['private_chat/','route_albums/','route_chat/','event_chat/','users/']){
  let query={prefix,autoPaginate:false,maxResults:250},count=0,tokens=0,pages=0;
  do {const [files,next]=await bucket.getFiles(query);for(const f of files){if(prefix==='users/'&&!/^users\/[^/]+\/business_claims\//.test(f.name))continue;count++;if(f.metadata?.metadata?.firebaseStorageDownloadTokens)tokens++;}query=next;pages++;}while(query&&pages<20);
  report.mediaInventory[prefix]={objects:count,tokenObjects:tokens,truncated:Boolean(query)};
 }
 fs.writeFileSync('audit-summary.json',JSON.stringify(report,null,2));console.log('AUDIT_SUMMARY '+JSON.stringify(report));
})().catch(e=>{console.error('Audit failed:',e.response?.status||e.code||e.message);process.exitCode=1;});
