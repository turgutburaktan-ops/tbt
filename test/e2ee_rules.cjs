const {test,before,after}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-tbt-general-audit',firestore:{rules:fs.readFileSync('firestore.rules','utf8')},storage:{rules:fs.readFileSync('storage.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  for(const uid of ['alice','bob'])await setDoc(doc(db,'users',uid),{accountStatus:'active'});
  await setDoc(doc(db,'chat_threads/e2ee'),{type:'direct',memberIds:['alice','bob'],e2eeVersion:1,lastMessage:'Şifreli mesaj'});
  await setDoc(doc(db,'chat_threads/e2ee/messages/secret'),{type:'e2ee',senderId:'alice',deleted:false,e2ee:{version:1}});
  await setDoc(doc(db,'travel_plans/secure'),{accountFrozen:false,ownerId:'alice',memberIds:['alice','bob'],e2eeVersion:1});
  await setDoc(doc(db,'social_events/secure'),{accountFrozen:false,hostId:'alice',participantIds:['bob'],status:'open',e2eeVersion:1});
  for(const [scope,parent,sub] of [['route','travel_plans','messages'],['event','social_events','chat']]) {
    await setDoc(doc(db,`${parent}/secure/${sub}/secret`),{type:'e2ee',senderId:'alice',deleted:false});
    await uploadBytes(ref(c.storage(),`e2ee_${scope}/secure/alice/secret/payload.bin`),new Uint8Array(40),{contentType:'application/octet-stream'});
  }
  await setDoc(doc(db,'e2ee_identities/alice'),{identityKey:'public-only'});
  await uploadBytes(ref(c.storage(),'e2ee_chat/e2ee/alice/secret/payload.bin'),new Uint8Array(40),{contentType:'application/octet-stream'});
 });
});
after(async()=>env?.cleanup());
test('clients cannot read key directory, replace identities, send plaintext or downgrade',async()=>{
 const db=env.authenticatedContext('alice').firestore();
 await assertFails(getDoc(doc(db,'e2ee_identities/alice')));
 await assertFails(setDoc(doc(db,'e2ee_identities/alice'),{identityKey:'replacement'}));
 await assertFails(updateDoc(doc(db,'chat_threads/e2ee'),{e2eeVersion:0}));
 await assertFails(updateDoc(doc(db,'chat_threads/e2ee'),{lastMessage:'plaintext leak'}));
 await assertFails(setDoc(doc(db,'chat_threads/e2ee/messages/plain'),{senderId:'alice',text:'secret',type:'text',deleted:false}));
 await assertSucceeds(updateDoc(doc(db,'chat_threads/e2ee'),{'typingAt.alice':null}));
});
test('ciphertext objects remain member-scoped and immutable',async()=>{
 const path='e2ee_chat/e2ee/alice/secret/payload.bin';
 await assertSucceeds(getBytes(ref(env.authenticatedContext('bob').storage(),path)));
 await assertFails(getBytes(ref(env.authenticatedContext('mallory').storage(),path)));
 await assertFails(getBytes(ref(env.unauthenticatedContext().storage(),path)));
 await assertFails(uploadBytes(ref(env.authenticatedContext('alice').storage(),path),new Uint8Array(40),{contentType:'application/octet-stream'}));
 await assertSucceeds(uploadBytes(ref(env.authenticatedContext('alice').storage(),'e2ee_chat/e2ee/alice/new/payload.bin'),new Uint8Array(40),{contentType:'application/octet-stream'}));
});

test('route/event encryption cannot be downgraded and media remains member-only',async()=>{
 for(const [scope,parent,sub] of [['route','travel_plans','messages'],['event','social_events','chat']]) {
  const db=env.authenticatedContext('alice').firestore(),path=`e2ee_${scope}/secure/alice/secret/payload.bin`;
  await assertFails(updateDoc(doc(db,`${parent}/secure`),{e2eeVersion:0}));
  await assertFails(setDoc(doc(db,`${parent}/secure/${sub}/plain`),{senderId:'alice',senderName:'Alice',text:'secret',type:'text',deleted:false}));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('bob').storage(),path)));
  await assertFails(getBytes(ref(env.authenticatedContext('mallory').storage(),path)));
  await assertFails(uploadBytes(ref(env.authenticatedContext('alice').storage(),path),new Uint8Array(40),{contentType:'application/octet-stream'}));
 }
});
