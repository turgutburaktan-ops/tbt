const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc}=require('firebase/firestore');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-tbt-general-audit',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'users/owner'),{uid:'owner',displayName:'Owner'});
  await setDoc(doc(c.firestore(),'private_users/owner'),{email:'synthetic@example.invalid',phoneNumber:'+900000000000'});
 });
});
after(async()=>env?.cleanup());
test('Contacts are owner-only while the social profile remains readable',async()=>{
 const other=env.authenticatedContext('other').firestore(),owner=env.authenticatedContext('owner').firestore();
 await assertFails(getDoc(doc(other,'private_users/owner')));
 await assertSucceeds(getDoc(doc(owner,'private_users/owner')));
 const p=await assertSucceeds(getDoc(doc(other,'users/owner')));assert.equal(p.data().email,undefined);
 await assertSucceeds(updateDoc(doc(owner,'users/owner'),{displayName:'Changed'}));
});
test('Neither new nor old client can reintroduce private contact fields',async()=>{
 const owner=env.authenticatedContext('owner').firestore(),newUser=env.authenticatedContext('new').firestore();
 for(const field of ['email','phoneNumber','verifiedPhoneNumber']){
  await assertFails(updateDoc(doc(owner,'users/owner'),{[field]:'synthetic'}));
  await assertFails(setDoc(doc(newUser,'users/new'),{uid:'new',[field]:'synthetic'}));
 }
 await assertSucceeds(setDoc(doc(newUser,'users/new'),{uid:'new',displayName:'New'}));
});
