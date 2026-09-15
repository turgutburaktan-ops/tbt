const test=require('node:test'),assert=require('node:assert/strict'),Module=require('node:module'),fs=require('node:fs'),path=require('node:path');
function harness(metadata={contentType:'image/jpeg',size:'1200'}){
 const records=new Map(),uploads=[];
 const db={collection:()=>({doc:id=>({id})}),runTransaction:async fn=>fn({get:async ref=>({exists:records.has(ref.id),data:()=>records.get(ref.id)}),create:(ref,data)=>records.set(ref.id,data)})};
 const loaded=new Module(__filename);loaded.filename=path.join(__dirname,'../admin_console.js');
 loaded.require=id=>id==='firebase-functions/v2/https'?{onCall:(_,fn)=>fn,HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}}}:id==='firebase-admin/firestore'?{getFirestore:()=>db,FieldValue:{serverTimestamp:()=>1}}:id==='firebase-admin/storage'?{getStorage:()=>({bucket:()=>({file:p=>{uploads.push(p);return {getMetadata:async()=>[metadata]};}})}),getDownloadURL:async()=> 'https://example.com/approved.jpg'}:id==='./broadcast_policy'?require('../broadcast_policy'):require(id);
 loaded._compile(fs.readFileSync(loaded.filename,'utf8'),loaded.filename);
 const auth={uid:'admin',token:{admin:true,email_verified:true,email:'turgutburaktan@gmail.com'}};
 const data={title:'Yeni duyuru',body:'Fotoğraf açıklaması',requestId:'photo_request_0001',imagePath:'admin_broadcasts/photo_request_0001/image.jpg'};
 return {send:(patch={},user=auth)=>loaded.exports.sendAdminBroadcast({auth:user,data:{...data,...patch}}),records,uploads};
}
test('announcement photo is admin-only and cannot reference another upload',async()=>{
 const h=harness();await assert.rejects(h.send({}, {uid:'viewer'}),e=>e.code==='permission-denied');assert.equal(h.uploads.length,0);
 await assert.rejects(h.send({imagePath:'users/someone/photo.jpg'}),e=>e.code==='invalid-argument');assert.equal(h.uploads.length,0);
});
test('photo metadata is checked before queuing a broadcast',async()=>{
 for(const meta of [{contentType:'text/html',size:1},{contentType:'image/jpeg',size:0},{contentType:'image/jpeg',size:11*1024*1024}]){
  const h=harness(meta);await assert.rejects(h.send(),e=>e.code==='invalid-argument');assert.equal(h.records.size,0);
 }
});
test('approved photo persists once; reusing request with changed content is rejected',async()=>{
 const h=harness();await h.send();await h.send();assert.equal(h.records.size,1);
 const job=h.records.values().next().value;assert.equal(job.imageUrl,'https://example.com/approved.jpg');assert.equal(job.imagePath,'admin_broadcasts/photo_request_0001/image.jpg');
 await assert.rejects(h.send({imagePath:''}),e=>e.code==='already-exists');
});
