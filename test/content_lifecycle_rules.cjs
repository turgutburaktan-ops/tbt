const {test,before,after} = require('node:test');
const fs = require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,deleteField,Timestamp} = require('firebase/firestore');
let env;
const db = uid => env.authenticatedContext(uid).firestore();
const content = uid => ({
  posts: {userId:uid, caption:'Test', mediaType:'image'},
  stories: {userId:uid, expiresAt:Timestamp.fromMillis(Date.now()+3600000)},
  social_events: {hostId:uid, status:'open', accessType:'free', visibility:'public'},
  event_memories: {userId:uid, eventId:'past'},
  communities: {ownerId:uid, verified:false, verificationStatus:'pending', adminIds:[uid], name:'Test'},
  travel_plans: {ownerId:uid, memberIds:[uid], visibility:'private', isPublic:false, spotIds:['spot'], title:'Test'},
});
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-tbt-content-lifecycle',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
  await env.withSecurityRulesDisabled(async c => {
    const d = c.firestore();
    for (const [uid,profile] of Object.entries({active:{accountStatus:'active'},legacy:{},frozen:{accountStatus:'frozen'},banned:{banned:true},disabled:{disabled:true},deleting:{accountStatus:'deleting'}})) await setDoc(doc(d,'users',uid),profile);
    await setDoc(doc(d,'social_events/past'),{hostId:'active',participantIds:['active','legacy','frozen','banned','disabled','deleting'],startsAt:Timestamp.fromMillis(1),status:'open',visibility:'public'});
    for (const [collection,data] of Object.entries(content('active'))) await setDoc(doc(d,collection,'existing'),{...data,accountFrozen:true,accountFrozenAt:Timestamp.fromMillis(1)});
  });
});
after(async () => env?.cleanup());
test('active and legacy users can publish each content type; restricted users cannot', async () => {
  for (const uid of ['active','legacy','frozen','banned','disabled','deleting']) {
    for (const [collection,data] of Object.entries(content(uid))) {
      const write = setDoc(doc(db(uid),collection,`create-${uid}`),data);
      await (['active','legacy'].includes(uid) ? assertSucceeds(write) : assertFails(write));
    }
  }
});
test('owners cannot clear, replace or remove server-owned freeze metadata', async () => {
  for (const collection of Object.keys(content('active'))) {
    const ref = doc(db('active'),collection,'existing');
    for (const patch of [{accountFrozen:false},{accountFrozen:deleteField()},{accountFrozenAt:deleteField()}]) await assertFails(updateDoc(ref,patch));
  }
});
test('active users cannot forge freeze metadata while creating content', async () => {
  for (const [collection,data] of Object.entries(content('active'))) {
    await assertFails(setDoc(doc(db('active'),collection,'forged'),{...data,accountFrozen:true}));
    await assertFails(setDoc(doc(db('active'),collection,'forged-time'),{...data,accountFrozenAt:Timestamp.fromMillis(1)}));
  }
});
test('ordinary edits remain available, but memory ownership is immutable', async () => {
  for (const [collection,patch] of [['posts',{caption:'Edited'}],['stories',{caption:'Edited'}],['event_memories',{caption:'Edited'}],['communities',{name:'Edited'}],['travel_plans',{title:'Edited'}]]) await assertSucceeds(updateDoc(doc(db('active'),collection,'existing'),patch));
  await assertFails(updateDoc(doc(db('active'),'event_memories/existing'),{userId:'other'}));
});
test('clients cannot create or read lifecycle operation locks', async () => {
  for (const uid of ['active','other']) {
    await assertFails(setDoc(doc(db(uid),'account_lifecycle_locks',uid),{token:'forged',expiresAtMs:0}));
    await assertFails(getDoc(doc(db(uid),'account_lifecycle_locks',uid)));
  }
});
test('an account without a profile cannot publish content', async () => {
  for (const [collection,data] of Object.entries(content('missing-profile'))) await assertFails(setDoc(doc(db('missing-profile'),collection,'missing-profile'),data));
});
