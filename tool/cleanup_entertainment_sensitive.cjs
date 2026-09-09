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
 const deleteIds=['tbt-eglence-reel-10','tbt-eglence-reel-13','tbt-eglence-reel-14','tbt-eglence-reel-18','tbt-eglence-reel-19','tbt-eglence-reel-20'];
 const deleted=[];
 for(const id of deleteIds){
   const ref=db.collection('posts').doc(id),snap=await ref.get();
   if(!snap.exists) continue;
   check(snap.data().userId===uid,`Unexpected reel owner: ${id}`);
   const d=snap.data();
   for(const p of [d.videoStoragePath,d.thumbnailStoragePath]){
     if(!p) continue;
     try{await bucket.file(p).delete();}catch(e){if(Number(e.code)!==404)throw e;}
   }
   await ref.delete();
   deleted.push(id);
 }
 const updates={
  'tbt-eglence-reel-11':{caption:'Gaziantep’te patlıcan kebabı hazırlanışı 😋🔥\n\nGaziantep mutfağının sevilen lezzetlerinden patlıcan kebabının hazırlanışından kısa bir kesit.'},
  'tbt-eglence-reel-12':{caption:'Maç sonu tribün coşkusu 🔴⚪\n\nSamsunspor–Ankara Keçiörengücü karşılaşmasının ardından yaşanan tribün ve saha atmosferinden kısa bir görüntü.'}
 };
 for(const [id,u] of Object.entries(updates)){
   const r=db.collection('posts').doc(id),s=await r.get();
   if(s.exists){check(s.data().userId===uid,'Unexpected reel owner');await r.update({...u,updatedAt:admin.firestore.FieldValue.serverTimestamp()});}
 }
 const verify=await db.getAll(...deleteIds.map(id=>db.collection('posts').doc(id)));
 check(verify.every(s=>!s.exists),'Noncompliant entertainment reel still exists');
 console.log(JSON.stringify({deleted,updated:['tbt-eglence-reel-11','tbt-eglence-reel-12'],policy:'real-video-women-focused-no-religion-no-folk-dance'}));
}
main().catch(e=>{console.error(e.stack||e.message);process.exitCode=1});
