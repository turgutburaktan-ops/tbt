'use strict';
const admin = require('firebase-admin');
const definitions = require('./ready_routes.json');
(async()=>{
 const account=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
 if(account.project_id!=='en-iyi-cekim-noktasi') throw Error('Unexpected project');
 admin.initializeApp({credential:admin.credential.cert(account)});
 const db=admin.firestore();
 const owner=await admin.auth().getUserByEmail('turgutburaktan@gmail.com');
 const refs=definitions.filter(d=>d.stops.length>=2).map(d=>db.collection('travel_plans').doc(d.id));
 await db.runTransaction(async tx=>{
  const docs=await tx.getAll(...refs);
  for(const doc of docs){
   if(!doc.exists) continue;
   const d=doc.data();
   if(d.readySeedVersion!==1 || d.ownerId!==owner.uid || d.hasSchedule!==false || d.joinEnabled!==false ||
      d.memberIds.some(id=>id!==owner.uid) || (d.invitedIds||[]).length) throw Error('Route was changed; refusing automatic repair: '+doc.id);
   tx.update(doc.ref,{memberIds:[],isPublic:true,visibility:'public',discoverPublished:true,updatedAt:admin.firestore.FieldValue.serverTimestamp()});
  }
 });
 const docs=await db.getAll(...refs);
 const publicDocs=await db.collection('travel_plans').where('isPublic','==',true).get();
 for(const doc of docs){
  if(!doc.exists) continue;
  const d=doc.data();
  if(d.memberIds.length || d.discoverPublished!==true || d.visibility!=='public' || !publicDocs.docs.some(p=>p.id===doc.id)) throw Error('Verification failed: '+doc.id);
  console.log('VERIFIED_DISCOVER_ONLY '+doc.id);
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
