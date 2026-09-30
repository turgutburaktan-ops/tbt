const {test,before,after}=require('node:test');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,collection,query,where,updateDoc}=require('firebase/firestore');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-tbt-frozen-posts',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  await setDoc(doc(db,'users/owner'),{accountStatus:'active'});
  for(const [id,frozen] of [['visible',false],['frozen',true]]) {
   await setDoc(doc(db,'posts',id),{userId:'owner',accountFrozen:frozen,caption:'synthetic',mediaType:'image'});
   for(const sub of ['likes','comments','tags']) await setDoc(doc(db,`posts/${id}/${sub}/sample`),{userId:'owner',text:'synthetic'});
  }
 });
});
after(async()=>env?.cleanup());
test('filtered public feed succeeds, unconstrained feed and frozen content fail',async()=>{
 for(const context of [env.unauthenticatedContext(),env.authenticatedContext('other'),env.authenticatedContext('owner')]) {
  const db=context.firestore();
  const result=await assertSucceeds(getDocs(query(collection(db,'posts'),where('accountFrozen','==',false))));
  assert.deepEqual(result.docs.map(d=>d.id),['visible']);
  await assertFails(getDocs(collection(db,'posts')));
  await assertFails(getDoc(doc(db,'posts/frozen')));
  for(const sub of ['likes','comments','tags']) await assertFails(getDocs(collection(db,`posts/frozen/${sub}`)));
 }
});
test('client cannot restore frozen visibility; creation requires explicit visible state',async()=>{
 const db=env.authenticatedContext('owner').firestore();
 await assertFails(updateDoc(doc(db,'posts/frozen'),{accountFrozen:false}));
 await assertFails(setDoc(doc(db,'posts/new'),{userId:'owner',caption:'synthetic',mediaType:'image'}));
 await assertSucceeds(setDoc(doc(db,'posts/new'),{userId:'owner',caption:'synthetic',mediaType:'image',accountFrozen:false}));
 await assertFails(getDoc(doc(db,'frozen_media/owner/objects/sample')));
});
