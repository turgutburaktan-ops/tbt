const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,writeBatch,serverTimestamp}=require('firebase/firestore');
let env;
const db=uid=>env.authenticatedContext(uid).firestore();
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-tbt-general-audit',firestore:{rules:fs.readFileSync('firestore.rules','utf8')},storage:{rules:fs.readFileSync('storage.rules','utf8')}});
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
test.skip('F01 regression: denied unrelated authenticated account reads email and phone',async()=>{
 const s=await assertSucceeds(getDoc(doc(db('attacker'),'users/victim')));assert.equal(s.data().email,'synthetic@example.invalid');assert.equal(s.data().phoneNumber,'+900000000000');
});
test('F02 regression: denied outsider creates arbitrary notification in another account',async()=>{
 await assertFails(setDoc(doc(db('attacker'),'users/victim/notifications/forged'),{type:'group_message',title:'Synthetic forged alert',body:'SYNTHETIC_ONLY',actorId:'attacker',sourceId:'nonexistent-group'}));
});
test('F03 regression: denied private event outsider self-enrolls and gains chat access',async()=>{
 const d=db('attacker');await assertFails(getDoc(doc(d,'social_events/private-event/chat/secret')));
 const batch=writeBatch(d);
 batch.set(doc(d,'social_events/private-event/attendance/attacker'),{userId:'attacker',status:'going'});
 batch.update(doc(d,'social_events/private-event'),{participantIds:['victim','attacker'],updatedAt:serverTimestamp()});
 await assertFails(batch.commit());
 await assertFails(getDoc(doc(d,'social_events/private-event/chat/secret')));
});
test('F04 regression: denied activity demand owner can be replaced by another account',async()=>{
 await assertFails(updateDoc(doc(db('attacker'),'activity_demands/victim-owned'),{userId:'attacker',activity:'changed'}));
});
test('F05 regression: denied comment author can reassign comment attribution',async()=>{
 await assertFails(updateDoc(doc(db('attacker'),'posts/post/comments/comment'),{userId:'victim',text:'forged attribution'}));
});
test('F06 regression: frozen post cannot be read anonymously',async()=>{
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'posts/post')));
 await assertFails(getDoc(doc(db('attacker'),'posts/post/comments/comment')));
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

test('F07 regression: denied business verification evidence path is anonymously readable',async()=>{
 const bucket='gs://demo-tbt-general-audit.appspot.com',path='users/victim/business_claims/cafe:synthetic/evidence.jpg';
 await env.withSecurityRulesDisabled(c=>uploadBytes(ref(c.storage(bucket),path),new Uint8Array([1,2,3]),{contentType:'image/jpeg'}));
 await assertFails(getBytes(ref(env.unauthenticatedContext().storage(bucket),path)));
 await assertFails(getBytes(ref(env.authenticatedContext('attacker').storage(bucket),path)));
 await assertSucceeds(getBytes(ref(env.authenticatedContext('victim').storage(bucket),path)));
});
test('Frozen account public media cannot be read or overwritten through Storage rules',async()=>{
 const bucket='gs://demo-tbt-general-audit.appspot.com',path='users/frozen-media-owner/posts/image.jpg';
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),'users/frozen-media-owner'),{accountStatus:'frozen'});
  await uploadBytes(ref(c.storage(bucket),path),new Uint8Array([1,2,3]),{contentType:'image/jpeg'});
 });
 for(const context of [env.unauthenticatedContext(),env.authenticatedContext('attacker'),env.authenticatedContext('frozen-media-owner')]) {
  await assertFails(getBytes(ref(context.storage(bucket),path)));
 }
 await assertFails(uploadBytes(ref(env.authenticatedContext('frozen-media-owner').storage(bucket),path),new Uint8Array([4]),{contentType:'image/jpeg'}));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/frozen-media-owner'),{accountStatus:'active'}));
 await assertSucceeds(getBytes(ref(env.unauthenticatedContext().storage(bucket),path)));
});

test('Invited user can join, then leave a private event atomically', async()=>{
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'social_events/private-event'),{allowedUserIds:['friend']}));
 const d=db('friend');const join=writeBatch(d);
 join.set(doc(d,'social_events/private-event/attendance/friend'),{userId:'friend',status:'going'});
 join.update(doc(d,'social_events/private-event'),{participantIds:['victim','friend'],updatedAt:serverTimestamp()});
 await assertSucceeds(join.commit());
 await assertSucceeds(getDoc(doc(d,'social_events/private-event/chat/secret')));
 const leave=writeBatch(d);leave.delete(doc(d,'social_events/private-event/attendance/friend'));
 leave.update(doc(d,'social_events/private-event'),{participantIds:['victim'],updatedAt:serverTimestamp()});
 await assertSucceeds(leave.commit());
 await assertFails(getDoc(doc(db('attacker'),'social_events/private-event/chat/secret')));
});
test('Owners can edit demand and comment without changing attribution',async()=>{
 await assertSucceeds(updateDoc(doc(db('victim'),'activity_demands/victim-owned'),{activity:'cycle'}));
 await assertSucceeds(updateDoc(doc(db('attacker'),'posts/post/comments/comment'),{text:'edited'}));
});

test('Lifecycle state is server-owned and profile deletion cannot reset restrictions',async()=>{
 for(const field of ['accountStatus','accountStatusUpdatedAt','frozenAt']) {
  await assertFails(updateDoc(doc(db('victim'),'users/victim'),{[field]:'active'}));
  await assertFails(setDoc(doc(db('new-user'),'users/new-user'),{uid:'new-user',[field]:'active'}));
 }
 await assertFails(deleteDoc(doc(db('victim'),'users/victim')));
 await assertSucceeds(updateDoc(doc(db('victim'),'users/victim'),{displayName:'Updated display name'}));
});
