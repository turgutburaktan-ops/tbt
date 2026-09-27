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
 // Read registration state only; never enable enforcement before real-client compatibility is verified.
 try {
  const apps=(await client.request({url:'https://firebaseappcheck.googleapis.com/v1/projects/330568532415/apps'})).data;
  summary.appCheck={registeredApps:apps.apps?.length||0,enforcementChanged:false};
 }catch(e){summary.appCheck={enforcementChanged:false,readStatus:e.response?.status||e.code};}
 console.log('CONFIG_HARDENING '+JSON.stringify(summary));
})().catch(e=>{console.error('Configuration hardening failed',e.response?.status||e.code||e.message);process.exitCode=1;});
