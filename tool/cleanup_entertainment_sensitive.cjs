'use strict';
const path=require('node:path');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'..');
const project='en-iyi-cekim-noktasi';
const bucketName=`${project}.firebasestorage.app`;
const uid='tbt-editorial-eglence';
const check=(ok,m)=>{if(!ok)throw Error(m)};
async function main(){
 const admin=createRequire(path.join(root,'functions/package.json'))('firebase-admin');
 const sa=JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT||'{}');
 check(sa.project_id===project,'Wrong project');
 admin.initializeApp({credential:admin.credential.cert(sa),projectId:project,storageBucket:bucketName});
 const db=admin.firestore(),bucket=admin.storage().bucket();
 const ref10=db.collection('posts').doc('tbt-eglence-reel-10');
 const snap10=await ref10.get();
 if(snap10.exists){
   check(snap10.data().userId===uid,'Unexpected reel owner');
   const d=snap10.data();
   for(const p of [d.videoStoragePath,d.thumbnailStoragePath]){
     if(!p) continue;
     try{await bucket.file(p).delete();}catch(e){if(Number(e.code)!==404)throw e;}
   }
   await ref10.delete();
 }
 const updates={
  'tbt-eglence-reel-11':{
    caption:'Gaziantep’te patlıcan kebabı hazırlanışı 😋🔥\n\nGaziantep mutfağının sevilen lezzetlerinden patlıcan kebabının hazırlanışından kısa bir kesit.'
  },
  'tbt-eglence-reel-12':{
    caption:'Maç sonu tribün coşkusu 🔴⚪\n\nSamsunspor–Ankara Keçiörengücü karşılaşmasının ardından yaşanan tribün ve saha atmosferinden kısa bir görüntü.'
  }
 };
 for(const [id,u] of Object.entries(updates)){
   const r=db.collection('posts').doc(id),s=await r.get();
   if(s.exists){check(s.data().userId===uid,'Unexpected reel owner');await r.update({...u,updatedAt:admin.firestore.FieldValue.serverTimestamp()});}
 }
 const verify10=await ref10.get();
 check(!verify10.exists,'Sensitive reel still exists');
 console.log(JSON.stringify({deleted:'tbt-eglence-reel-10',updated:['tbt-eglence-reel-11','tbt-eglence-reel-12'],sensitivePolicy:'religion-excluded-from-entertainment'}));
}
main().catch(e=>{console.error(e.stack||e.message);process.exitCode=1});
