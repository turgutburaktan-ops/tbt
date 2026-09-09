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
 const deleteIds=['tbt-eglence-reel-10','tbt-eglence-reel-13','tbt-eglence-reel-14'];
 for(const id of deleteIds){
   const ref=db.collection('posts').doc(id),snap=await ref.get();
   if(!snap.exists) continue;
   check(snap.data().userId===uid,'Unexpected reel owner');
   const d=snap.data();
   for(const p of [d.videoStoragePath,d.thumbnailStoragePath]){
     if(!p) continue;
     try{await bucket.file(p).delete();}catch(e){if(Number(e.code)!==404)throw e;}
   }
   await ref.delete();
 }
 const updates={
  'tbt-eglence-reel-11':{caption:'Gaziantep’te patlıcan kebabı hazırlanışı 😋🔥\n\nGaziantep mutfağının sevilen lezzetlerinden patlıcan kebabının hazırlanışından kısa bir kesit.'},
  'tbt-eglence-reel-12':{caption:'Maç sonu tribün coşkusu 🔴⚪\n\nSamsunspor–Ankara Keçiörengücü karşılaşmasının ardından yaşanan tribün ve saha atmosferinden kısa bir görüntü.'}
 };
 for(const [id,u] of Object.entries(updates)){
   const r=db.collection('posts').doc(id),s=await r.get();
   if(s.exists){check(s.data().userId===uid,'Unexpected reel owner');await r.update({...u,updatedAt:admin.firestore.FieldValue.serverTimestamp()});}
 }
 for(const id of deleteIds){const v=await db.collection('posts').doc(id).get();check(!v.exists,`${id} still exists`);}
 console.log(JSON.stringify({deleted:deleteIds,updated:['tbt-eglence-reel-11','tbt-eglence-reel-12'],policy:'real-video-only-and-sensitive-content-filter'}));
}
main().catch(e=>{console.error(e.stack||e.message);process.exitCode=1});
