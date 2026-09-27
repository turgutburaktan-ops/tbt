const test=require('node:test'),assert=require('node:assert/strict');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc}=require('firebase/firestore');
const {project}=require('./store');
const {refreshPartition}=require('./importer');
initializeApp({projectId:'demo-tbt'});const db=getFirestore();
test('publication, repeated events, city moves, revocation, and failed source refresh',async()=>{
  const source=db.doc('business_venues/cafe:user_test');
  await source.set({verified:true,venueId:'user_test',category:'cafe',venueName:'Test',city:'Elazığ',latitude:38.67,longitude:39.22,ownerUid:'private'});
  await project(db,'venue','cafe:user_test');await project(db,'venue','cafe:user_test');
  const old=db.doc('place_catalog/elazig_cafe');
  assert.equal((await old.get()).data().count,1);
  assert.equal((await old.collection('items').doc('venue:cafe:user_test').get()).data().ownerUid,undefined);
  await source.update({city:'Ankara',latitude:39.9,longitude:32.8});await project(db,'venue','cafe:user_test');
  assert.equal((await old.get()).data().count,0);
  const dest=db.doc('place_catalog/ankara_cafe');assert.equal((await dest.get()).data().count,1);
  const result=await refreshPartition(db,'Ankara','cafe',async()=>({ok:false,status:504}));
  assert.equal(result.ok,false);assert.equal((await dest.get()).data().count,1);
  await source.delete();await project(db,'venue','cafe:user_test',{removedApprovedBusiness:true});
  await db.doc('catalog_external_venues/cafe:user_test').set({status:'published',category:'cafe',venueId:'user_test',venueName:'Test',city:'Ankara',latitude:39.9,longitude:32.8});
  await project(db,'venue','cafe:user_test');
  assert.equal((await dest.collection('items').doc('venue:cafe:user_test').get()).exists,false);
  // A delayed event re-reads the present source, never resurrecting old approval.
  await project(db,'venue','cafe:user_test',{removedApprovedBusiness:true});
  assert.equal((await dest.get()).data().count,0);
});
test('public catalog reads; all client writes and private import reads denied',async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-tbt',firestore:{host:'127.0.0.1',port:8080}});
  try{
    const anon=env.unauthenticatedContext().firestore(),member=env.authenticatedContext('member').firestore();
    await assertSucceeds(getDoc(doc(anon,'place_catalog/ankara_cafe')));
    await assertSucceeds(getDoc(doc(anon,'place_catalog/ankara_cafe/items/venue:cafe:user_test')));
    await assertFails(setDoc(doc(member,'place_catalog/ankara_cafe/items/forged'),{name:'Forged'}));
    for(const path of ['catalog_external_venues','catalog_links','catalog_exclusions','catalog_jobs']){
      await assertFails(getDoc(doc(member,path+'/test')));
      await assertFails(setDoc(doc(member,path+'/test'),{anything:true}));
    }
  }finally{await env.cleanup();}
});
