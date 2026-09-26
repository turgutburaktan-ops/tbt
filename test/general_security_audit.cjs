const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,writeBatch,serverTimestamp}=require('firebase/firestore');
let env;
const db=uid=>env.authenticatedContext(uid).firestore();
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-tbt-general-audit',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  await setDoc(doc(d,'users/victim'),{uid:'victim',email:'synthetic@example.invalid',phoneNumber:'+900000000000',displayName:'Synthetic',reputationTotal:100});
  await setDoc(doc(d,'activity_demands/victim-owned'),{userId:'victim',activity:'walk'});
  await setDoc(doc(d,'posts/post'),{userId:'victim',caption:'synthetic',accountFrozen:true});
  await setDoc(doc(d,'posts/post/comments/comment'),{userId:'attacker',text:'synthetic'});
  await setDoc(doc(d,'social_events/private-event'),{hostId:'victim',visibility:'private',allowedUserIds:[],participantIds:['victim'],status:'open',capacity:10,interestedCount:0,privateParticipantCount:0});
  await setDoc(doc(d,'social_events/private-event/chat/secret'),{senderId:'victim',text:'SYNTHETIC_ONLY'});
  await setDoc(doc(d,'chat_threads/secure-thread'),{type:'direct',memberIds:['victim','friend']});
  await setDoc(doc(d,'chat_threads/secure-thread/messages/private'),{senderId:'victim',text:'SYNTHETIC_ONLY'});
 });
});
after(async()=>env?.cleanup());
test('F01 confirmed: unrelated authenticated account reads email and phone',async()=>{
 const s=await assertSucceeds(getDoc(doc(db('attacker'),'users/victim')));assert.equal(s.data().email,'synthetic@example.invalid');assert.equal(s.data().phoneNumber,'+900000000000');
});
test('F02 confirmed: outsider creates arbitrary notification in another account',async()=>{
 await assertSucceeds(setDoc(doc(db('attacker'),'users/victim/notifications/forged'),{type:'group_message',title:'Synthetic forged alert',body:'SYNTHETIC_ONLY',actorId:'attacker',sourceId:'nonexistent-group'}));
});
test('F03 confirmed: private event outsider self-enrolls and gains chat access',async()=>{
 const d=db('attacker');await assertFails(getDoc(doc(d,'social_events/private-event/chat/secret')));
 const batch=writeBatch(d);
 batch.set(doc(d,'social_events/private-event/attendance/attacker'),{userId:'attacker',status:'going'});
 batch.update(doc(d,'social_events/private-event'),{participantIds:['victim','attacker'],updatedAt:serverTimestamp()});
 await assertSucceeds(batch.commit());
 const s=await assertSucceeds(getDoc(doc(d,'social_events/private-event/chat/secret')));assert.equal(s.data().text,'SYNTHETIC_ONLY');
});
test('F04 confirmed: activity demand owner can be replaced by another account',async()=>{
 await assertSucceeds(updateDoc(doc(db('attacker'),'activity_demands/victim-owned'),{userId:'attacker',activity:'changed'}));
});
test('F05 confirmed: comment author can reassign comment attribution',async()=>{
 await assertSucceeds(updateDoc(doc(db('attacker'),'posts/post/comments/comment'),{userId:'victim',text:'forged attribution'}));
});
test('F06 confirmed: frozen post remains readable anonymously',async()=>{
 await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(),'posts/post')));
});
test('P01 protected: outsiders cannot read normal direct message documents',async()=>{
 await assertFails(getDoc(doc(db('attacker'),'chat_threads/secure-thread/messages/private')));
});
test('P02 protected: self assigning admin or reputation is denied',async()=>{
 await assertFails(updateDoc(doc(db('victim'),'users/victim'),{admin:true}));
 await assertFails(updateDoc(doc(db('victim'),'users/victim'),{reputationTotal:999999}));
});
test('P03 protected: other users cannot read device tokens or admin audit',async()=>{
 await assertFails(getDoc(doc(db('attacker'),'users/victim/push_tokens/token')));
 await assertFails(getDoc(doc(db('attacker'),'admin_audit_logs/log')));
});
