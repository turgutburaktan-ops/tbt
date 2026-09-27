// Run only after the contact-free client release is available to every supported client.
// Copy and delete occur in one transaction; no contact values are printed.
const {initializeApp}=require('../functions/node_modules/firebase-admin/app');
const {getFirestore,FieldValue}=require('../functions/node_modules/firebase-admin/firestore');
initializeApp({projectId:'en-iyi-cekim-noktasi'});
const fields=['email','phoneNumber','verifiedPhoneNumber'];
(async()=>{
 if(process.env.CONTACT_FREE_CLIENT_RELEASED!=='true')throw Error('Contact-free client rollout must finish before migration and field-write denial');
 const db=getFirestore();let cursor=null,count=0;
 while(true){let q=db.collection('users').orderBy('__name__').limit(200);if(cursor)q=q.startAfter(cursor);
 const page=await q.get();if(page.empty)break;
 for(const doc of page.docs){await db.runTransaction(async tx=>{
  const current=await tx.get(doc.ref),d=current.data()||{},privateData={},remove={};
  for(const field of fields)if(Object.hasOwn(d,field)){privateData[field]=d[field];remove[field]=FieldValue.delete();}
  if(!Object.keys(remove).length)return;
  tx.set(db.doc(`private_users/${doc.id}`),{...privateData,migratedAt:FieldValue.serverTimestamp()},{merge:true});tx.update(doc.ref,remove);
 });count++;}cursor=page.docs.at(-1);
 }
 console.log('PRIVATE_CONTACT_MIGRATION '+JSON.stringify({processedUsers:count}));
})().catch(e=>{console.error(e.code||e.message);process.exitCode=1;});
