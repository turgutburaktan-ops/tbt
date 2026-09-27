const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
(async()=>{
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const project='en-iyi-cekim-noktasi';
 const summary={};
 const authUrl='https://identitytoolkit.googleapis.com/admin/v2/projects/'+project+'/config';
 try {
  const current=(await client.request({url:authUrl})).data;
  const old=current.passwordPolicyConfig||{};
  const strength=old.passwordPolicyVersions?.[0]?.customStrengthOptions||{};
  const policy={passwordPolicyEnforcementState:'ENFORCE',forceUpgradeOnSignin:old.forceUpgradeOnSignin||false,
   passwordPolicyVersions:[{customStrengthOptions:{...strength,minPasswordLength:Math.max(10,strength.minPasswordLength||0)}}]};
  await client.request({url:authUrl,method:'PATCH',params:{updateMask:'passwordPolicyConfig'},data:{passwordPolicyConfig:policy}});
  const verified=(await client.request({url:authUrl})).data.passwordPolicyConfig;
  if(verified?.passwordPolicyEnforcementState!=='ENFORCE'||verified.passwordPolicyVersions?.[0]?.customStrengthOptions?.minPasswordLength<10)throw Error('Password policy readback failed');
  summary.passwordPolicy={enforcement:verified.passwordPolicyEnforcementState,minimumLength:verified.passwordPolicyVersions[0].customStrengthOptions.minPasswordLength};
 } catch(e) {summary.passwordPolicy={completed:false,status:e.response?.status||e.code||e.message};}
 const dbUrl='https://firestore.googleapis.com/v1/projects/'+project+'/databases/(default)';
 try {
  const current=(await client.request({url:dbUrl})).data;
  const patch={pointInTimeRecoveryEnablement:'POINT_IN_TIME_RECOVERY_ENABLED',deleteProtectionState:'DELETE_PROTECTION_ENABLED'};
  if(current.pointInTimeRecoveryEnablement!==patch.pointInTimeRecoveryEnablement||current.deleteProtectionState!==patch.deleteProtectionState)
   await client.request({url:dbUrl,method:'PATCH',params:{updateMask:Object.keys(patch).join(',')},data:patch});
  const verified=(await client.request({url:dbUrl})).data;
  summary.databaseRecovery={pointInTimeRecoveryEnablement:verified.pointInTimeRecoveryEnablement,deleteProtectionState:verified.deleteProtectionState};
 } catch(e) {summary.databaseRecovery={completed:false,status:e.response?.status||e.code||e.message};}
 // Inspect each registered app via the Management API; App Check has no apps-list endpoint.
 // Report only registration status, never provider credentials or private keys.
 summary.appCheck={enforcementChanged:false,apps:[]};
 for(const [platform,resource,providers] of [
  ['android','androidApps',['playIntegrityConfig']],
  ['ios','iosApps',['appAttestConfig','deviceCheckConfig']],
 ]) {
  try {
   let pageToken;
   do {
    const page=(await client.request({url:`https://firebase.googleapis.com/v1beta1/projects/${project}/${resource}`,params:{pageSize:100,...(pageToken?{pageToken}:{})}})).data;
    for(const app of page.apps||[]) {
     const result={platform,appId:app.appId,providers:{}};
     for(const provider of providers) {
      try {
       await client.request({url:`https://firebaseappcheck.googleapis.com/v1/projects/330568532415/apps/${encodeURIComponent(app.appId)}/${provider}`});
       result.providers[provider]='registered';
      }catch(e){result.providers[provider]=e.response?.status===404?'not-registered':`unverified-http-${e.response?.status||'unknown'}`;}
     }
     summary.appCheck.apps.push(result);
    }
    pageToken=page.nextPageToken;
   }while(pageToken);
  }catch(e){summary.appCheck[platform+'ReadStatus']=e.response?.status||e.code;}
 }
 try {
  const services=(await client.request({url:'https://firebaseappcheck.googleapis.com/v1/projects/330568532415/services',params:{pageSize:100}})).data;
  summary.appCheck.services=(services.services||[]).map(s=>({name:s.name,enforcementMode:s.enforcementMode}));
 }catch(e){summary.appCheck.serviceReadStatus=e.response?.status||e.code;}
 console.log('CONFIG_HARDENING '+JSON.stringify(summary));
})().catch(e=>{console.error('Configuration hardening failed',e.response?.status||e.code||e.message);process.exitCode=1;});
