// Run only after the contact-free client release is available to every supported client.
// Copy and delete occur in one transaction; no contact values are printed.
const {initializeApp}=require('../functions/node_modules/firebase-admin/app');
const {getFirestore,FieldValue}=require('../functions/node_modules/firebase-admin/firestore');
initializeApp({projectId:'en-iyi-cekim-noktasi'});
const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
const {patchContactRules}=require('./contact_privacy_rules.cjs');
const {CONTACT_FIELDS: fields, migrateContactRecord} = require('./private_contact_migration.cjs');
(async()=>{
 if(process.env.CONTACT_FREE_CLIENT_RELEASED!=='true')throw Error('Contact-free client rollout must finish before migration and field-write denial');
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const base='https://firebaserules.googleapis.com/v1/';
 const live=(await client.request({url:base+'projects/en-iyi-cekim-noktasi/releases/cloud.firestore'})).data;
 const rules=(await client.request({url:base+live.rulesetName})).data;
 if(rules.source.files.length!==1||patchContactRules(rules.source.files[0].content)!==rules.source.files[0].content)throw Error('Contact field writes must be denied before migration');
 const db=getFirestore();let cursor=null,count=0;
 while(true){let q=db.collection('users').orderBy('__name__').limit(200);if(cursor)q=q.startAfter(cursor);
 const page=await q.get();if(page.empty)break;
 for(const doc of page.docs){
  if(await migrateContactRecord({db,publicRef:doc.ref,privateRef:db.doc(`private_users/${doc.id}`),fieldValue:FieldValue}))count++;
 }cursor=page.docs.at(-1);
 }
 cursor=null;let remaining=0;
 while(true){let q=db.collection('users').orderBy('__name__').select(...fields).limit(200);if(cursor)q=q.startAfter(cursor);
  const page=await q.get();if(page.empty)break;
  for(const doc of page.docs)if(fields.some(field=>Object.hasOwn(doc.data(),field)))remaining++;
  cursor=page.docs.at(-1);
 }
 if(remaining)throw Error('Public contact cleanup verification failed');
 console.log('PRIVATE_CONTACT_MIGRATION '+JSON.stringify({processedUsers:count,remainingPublicContacts:remaining}));
})().catch(e=>{console.error(e.code||e.message);process.exitCode=1;});
