'use strict';
// Clients independently verify that their store offers the target version before
// making an update mandatory. This policy never asserts store availability.
const fromFunctions=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {initializeApp,cert}=fromFunctions('firebase-admin/app');
const {getFirestore,FieldValue}=fromFunctions('firebase-admin/firestore');
const account=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
if(account.project_id!=='en-iyi-cekim-noktasi')throw Error('Unexpected project');
initializeApp({credential:cert(account),projectId:account.project_id});
(async()=>{
 const db=getFirestore(),ref=db.doc('app_config/update_policy');
 const rank=v=>String(v||'0').split('.').map(Number).reduce((n,x)=>n*1000+x,0);
 await db.runTransaction(async tx=>{
  const current=(await tx.get(ref)).data()||{};
  if((current.androidMinimumBuild||0)>64||rank(current.iosMinimumVersion)>1000036)throw Error('Newer policy exists; refusing older release');
  tx.set(ref,{androidMinimumBuild:64,iosMinimumVersion:'1.0.36',updatedAt:FieldValue.serverTimestamp()},{merge:true});
 });
 const current=(await ref.get()).data();
 if(current.androidMinimumBuild!==64||current.iosMinimumVersion!=='1.0.36')throw Error('Policy readback mismatch');
 console.log('RELEASE64_UPDATE_POLICY_ARMED: mandatory only when the device store offers 64 / 1.0.36');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
