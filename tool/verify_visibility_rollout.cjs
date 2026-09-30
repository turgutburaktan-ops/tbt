// Read-only completion check. Never treats an unexamined document as compatible.
const fromFunctions=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {initializeApp}=fromFunctions('firebase-admin/app');
const {getFirestore}=fromFunctions('firebase-admin/firestore');
const {backfillContent,owners}=require('../functions/content_visibility');
initializeApp({projectId:'en-iyi-cekim-noktasi'});
(async()=>{
 const db=getFirestore(),counts={};let incompatible=0;
 for(const collection of Object.keys(owners)){
  let cursor;counts[collection]=0;
  while(true){let q=db.collection(collection).orderBy('__name__').limit(100);if(cursor)q=q.startAfter(cursor);const page=await q.get();if(page.empty)break;
   for(const doc of page.docs){const result=await backfillContent({db,ref:doc.ref});if(result!=='unchanged'&&result!=='deleted')incompatible++;counts[collection]++;}cursor=page.docs.at(-1);
  }
  await db.collection(collection).where('accountFrozen','==',false).limit(1).select().get();
 }
 console.log('VISIBILITY_ROLLOUT_VERIFIED '+JSON.stringify({counts,incompatible}));if(incompatible)throw Error('Some content still needs migration');
})().catch(e=>{console.error(e.code||e.message);process.exitCode=1;});
