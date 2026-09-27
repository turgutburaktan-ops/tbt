const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const Module=require('node:module');
const {readFileSync}=require('node:fs');
const {resolve}=require('node:path');
const inMemory=process.env.TBT_TEST_IN_MEMORY==='1';
const adminApp=inMemory?null:require('firebase-admin/app');
const adminStore=inMemory?null:require('firebase-admin/firestore');
let app,db,api;
before(()=>{
 if(inMemory) db=require('./support/memory_firestore.cjs').memoryFirestore();
 else {app=adminApp.initializeApp({projectId:'demo-tbt-access'});db=adminStore.getFirestore(app);}
 const mod=new Module(__filename);mod.filename=resolve('functions/spot_submission.js');
 mod.require=id=>id==='firebase-functions/v2/https'?{onCall:(_,fn)=>fn,HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}}}:id==='firebase-admin/firestore'&&inMemory?{getFirestore:()=>db,FieldValue:{serverTimestamp:()=>new Date().toISOString()}}:require(id);
 mod._compile(readFileSync(mod.filename,'utf8'),mod.filename);api=mod.exports;
});
after(()=>inMemory?undefined:adminApp.deleteApp(app));
beforeEach(async()=>{
 for(const col of ['travel_plans','spot_submissions','photo_spots','spot_submission_review_locks']) await db.recursiveDelete(db.collection(col));
 await db.doc('travel_plans/route').set({memberIds:['owner','member'],stopSnapshots:[{id:'custom_1'},{id:'custom_2'},{id:'catalog_1'},{id:'map:38.600000,39.200000'}]});
});
function request(uid='member',data={}) {return {auth:{uid,token:{}},data:{name:'Yeni seyir noktası',city:'Elazığ',description:'Vadi manzarası olan bir nokta',whyVisit:'Gün batımı manzarası',latitude:38.6,longitude:39.2,imageUrl:'https://example.test/photo.jpg',imageStoragePath:`users/${uid}/spot_submissions/1/photo.jpg`,sourceRouteId:'route',sourceStopId:'custom_1',...data}};}
const review=(id,decision='approved')=>api.reviewSpotSuggestion({auth:{uid:'admin',token:{admin:true,email:'turgutburaktan@gmail.com'}},data:{submissionId:id,decision}});
test('route suggestions require membership and a custom non-business stop',async()=>{
 await assert.rejects(api.submitSpotSuggestion(request('outsider')),e=>e.code==='permission-denied');
 await assert.rejects(api.submitSpotSuggestion(request('member',{sourceStopId:'catalog_1'})),e=>e.code==='failed-precondition');
 await assert.rejects(api.submitSpotSuggestion(request('member',{sourceStopId:'custom_missing'})),e=>e.code==='failed-precondition');
 await assert.rejects(api.submitSpotSuggestion(request('member',{imageStoragePath:'users/other/spot_submissions/p.jpg'})),e=>e.code==='permission-denied');
});
test('map-selected stops can be suggested with their original source identity',async()=>{
 const r=await api.submitSpotSuggestion(request('member',{sourceStopId:'map:38.600000,39.200000'}));
 assert.equal((await db.doc(`spot_submissions/${r.id}`).get()).data().sourceStopId,'map:38.600000,39.200000');
});
test('repeated concurrent submissions create one pending suggestion',async()=>{
 const results=await Promise.all([api.submitSpotSuggestion(request()),api.submitSpotSuggestion(request())]);
 assert.equal(results[0].id,results[1].id);
 assert.equal((await db.collection('spot_submissions').get()).size,1);
 assert.equal((await db.collection('photo_spots').get()).size,0);
 assert.equal(results.filter(r=>r.alreadySubmitted).length,1);
});
test('duplicate detection checks beyond 100 records and legacy city-only entries',async()=>{
 const batch=db.batch();for(let i=0;i<130;i++)batch.set(db.doc(`photo_spots/p${i}`),{city:'Elazığ',name:`Yer ${i}`,latitude:40+i/10000,longitude:40});
 batch.set(db.doc('photo_spots/z-last'),{city:'Elazığ',name:'Yeni seyir noktası',latitude:38.6,longitude:39.2});await batch.commit();
 const result=await api.submitSpotSuggestion(request());assert.equal(result.duplicateWarning,true);
 await assert.rejects(review(result.id),e=>e.code==='already-exists');
 await review(result.id,'duplicate');assert.equal((await db.doc(`spot_submissions/${result.id}`).get()).data().status,'duplicate');
});
test('two approvals of the same place publish exactly once and preserve source attribution',async()=>{
 const a=await api.submitSpotSuggestion(request());
 const b=await api.submitSpotSuggestion(request('member',{sourceStopId:'custom_2'}));
 const results=await Promise.allSettled([review(a.id),review(b.id)]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const spots=await db.collection('photo_spots').get();assert.equal(spots.size,1);
 assert.equal(spots.docs[0].data().submittedBy,'member');
 const winner=results[0].status==='fulfilled'?a:b;
 await assert.rejects(review(winner.id),e=>e.code==='failed-precondition');
});
test('rejected suggestions can be corrected; non-admin users cannot approve',async()=>{
 const a=await api.submitSpotSuggestion(request());await review(a.id,'rejected');
 const retry=await api.submitSpotSuggestion(request('member',{description:'Düzeltilmiş gezi açıklaması'}));
 assert.equal(retry.id,a.id);assert.equal(retry.status,'pending_review');
 await assert.rejects(api.reviewSpotSuggestion({auth:{uid:'member',token:{}},data:{submissionId:a.id,decision:'approved'}}),e=>e.code==='permission-denied');
});
