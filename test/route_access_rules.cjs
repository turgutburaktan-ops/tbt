const {readFileSync}=require('node:fs');
const {test,before,after,beforeEach}=require('node:test');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {collection,query,where,getDocs,doc,setDoc,getDoc,updateDoc,arrayUnion,arrayRemove,serverTimestamp,Timestamp,runTransaction}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-tbt-access',firestore:{rules:readFileSync('firestore.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
const db=uid=>env.authenticatedContext(uid).firestore();
const base=()=>({ownerId:'owner',memberIds:['owner'],invitedIds:['invite'],visibility:'public',isPublic:true,
 accessVersion:2,joinAudience:'followers',joinEnabled:true,joinRequiresApproval:false,
 hasSchedule:true,startAt:Timestamp.fromMillis(Date.now()+86400000),participantLimit:60,spotIds:['s'],title:'Rota'});
async function seed(extra={}) {await env.withSecurityRulesDisabled(async c=>{
 await setDoc(doc(c.firestore(),'travel_plans/r'),{...base(),...extra});
 await setDoc(doc(c.firestore(),'users/owner/followers/follower'),{userId:'follower'});
});}
beforeEach(async()=>{await env.clearFirestore();await seed();});
const join=uid=>updateDoc(doc(db(uid),'travel_plans/r'),{memberIds:arrayUnion(uid),invitedIds:arrayRemove(uid),updatedAt:serverTimestamp()});
const request=uid=>setDoc(doc(db(uid),`travel_plans/r/join_requests/${uid}`),{userId:uid,name:uid,status:'pending',updatedAt:serverTimestamp()});
test('public visibility does not grant non-followers participation',async()=>{
 await assertSucceeds(getDoc(doc(db('outsider'),'travel_plans/r')));
 await assertFails(join('outsider'));
 await assertSucceeds(join('follower'));
});
test('approval cannot be bypassed by joining directly',async()=>{
 await seed({joinRequiresApproval:true});
 await assertFails(join('follower'));await assertSucceeds(request('follower'));
 await assertFails(request('outsider'));
});
test('public direct participation permits eligible outsiders',async()=>{
 await seed({joinAudience:'public'});await assertSucceeds(join('outsider'));
});
test('private invite can read but cannot access chat/album before accepting',async()=>{
 await seed({visibility:'private',isPublic:false,joinAudience:'private',joinRequiresApproval:false});
 await assertSucceeds(getDoc(doc(db('invite'),'travel_plans/r')));
 await assertFails(getDoc(doc(db('outsider'),'travel_plans/r')));
 await assertFails(getDoc(doc(db('invite'),'travel_plans/r/messages/m')));
 await assertFails(getDoc(doc(db('invite'),'travel_plans/r/album/a')));
 await assertSucceeds(join('invite'));
 await assertSucceeds(getDoc(doc(db('invite'),'travel_plans/r/messages/m')));
});
test('explicit invitation overrides follower and approval requirements',async()=>{
 await seed({visibility:'followers',isPublic:false,joinRequiresApproval:true});
 await assertSucceeds(join('invite'));
});
test('invite decline removes only the current invite',async()=>{
 await assertSucceeds(updateDoc(doc(db('invite'),'travel_plans/r'),{invitedIds:arrayRemove('invite'),updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(db('outsider'),'travel_plans/r'),{invitedIds:[],updatedAt:serverTimestamp()}));
});
test('closed, expired and full routes reject new participation',async()=>{
 for(const extra of [{joinEnabled:false},{startAt:Timestamp.fromMillis(1)},{participantLimit:1}]) {
  await seed(extra);await assertFails(join('follower'));await assertFails(join('invite'));
 }
});
test('self join cannot add others, replace members or change policy',async()=>{
 const ref=doc(db('follower'),'travel_plans/r');
 for(const changes of [{memberIds:['owner','follower','outsider']},{memberIds:['follower']},{memberIds:['owner','follower'],joinAudience:'public'}]) {
  await assertFails(updateDoc(ref,{...changes,updatedAt:serverTimestamp()}));
 }
});
test('owner cannot save conflicting audiences or invalid approval values',async()=>{
 const ref=doc(db('owner'),'travel_plans/r');
 await assertFails(updateDoc(ref,{visibility:'private',isPublic:false,joinAudience:'public'}));
 await assertFails(updateDoc(ref,{joinRequiresApproval:'false'}));
 await assertSucceeds(updateDoc(ref,{visibility:'private',isPublic:false,joinAudience:'private'}));
});
test('only one person can claim the final place with concurrent transactions',async()=>{
 await seed({joinAudience:'public',participantLimit:2});
 const attempt=uid=>{const store=db(uid);return runTransaction(store,async tx=>{
  const ref=doc(store,'travel_plans/r');const d=(await tx.get(ref)).data();
  if(d.memberIds.length>=d.participantLimit) throw Error('full');
  tx.update(ref,{memberIds:[...d.memberIds,uid],invitedIds:d.invitedIds.filter(x=>x!==uid),updatedAt:serverTimestamp()});
 });};
 const result=await Promise.allSettled([attempt('one'),attempt('two')]);
 require('node:assert/strict').equal(result.filter(x=>x.status==='fulfilled').length,1);
});

test('only an owner can publish and discovery publication requires public visibility',async()=>{
 await assertFails(updateDoc(doc(db('follower'),'travel_plans/r'),{discoverPublished:true}));
 await assertSucceeds(updateDoc(doc(db('owner'),'travel_plans/r'),{discoverPublished:true}));
 await assertFails(updateDoc(doc(db('owner'),'travel_plans/r'),{visibility:'private',isPublic:false,joinAudience:'private'}));
 await assertSucceeds(updateDoc(doc(db('owner'),'travel_plans/r'),{visibility:'private',isPublic:false,joinAudience:'private',discoverPublished:false}));
 await assertFails(getDoc(doc(db('outsider'),'travel_plans/r')));
});
test('bookmark does not grant route, album or chat access',async()=>{
 await seed({visibility:'private',isPublic:false,joinAudience:'private'});
 await assertSucceeds(setDoc(doc(db('outsider'),'users/outsider/saved_routes/r'),{routeId:'r',createdAt:serverTimestamp()}));
 await assertFails(getDoc(doc(db('outsider'),'travel_plans/r')));
 await assertFails(getDoc(doc(db('outsider'),'travel_plans/r/album/a')));
});

test('editorial IDs are reserved while personal copies remain allowed',async()=>{
 const data={...base(),visibility:'private',isPublic:false,joinEnabled:false,joinAudience:'private',hasSchedule:false,invitedIds:[]};
 await assertFails(setDoc(doc(db('owner'),'travel_plans/tbt_ready_fake'),data));
 await assertSucceeds(setDoc(doc(db('owner'),'travel_plans/personal_copy'),data));
});

test('public editorial routes without participants are discoverable but absent from personal plans',async()=>{
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'travel_plans/tbt_ready_example'),{
  ...base(),memberIds:[],invitedIds:[],joinEnabled:false,hasSchedule:false,discoverPublished:true
 }));
 const discover=await assertSucceeds(getDocs(query(collection(db('owner'),'travel_plans'),where('isPublic','==',true))));
 if(!discover.docs.some(d=>d.id==='tbt_ready_example')) throw Error('Editorial route missing from Discover');
 const mine=await assertSucceeds(getDocs(query(collection(db('owner'),'travel_plans'),where('memberIds','array-contains','owner'))));
 if(mine.docs.some(d=>d.id==='tbt_ready_example')) throw Error('Editorial route leaked into personal plans');
 await assertSucceeds(getDoc(doc(db('outsider'),'travel_plans/tbt_ready_example')));
});
test('update policy is readable before sign-in but cannot be changed by clients',async()=>{
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'app_config/update_policy'),{androidMinimumBuild:0,iosMinimumVersion:'0.0.0'}));
 await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(),'app_config/update_policy')));
 await assertFails(setDoc(doc(db('owner'),'app_config/update_policy'),{androidMinimumBuild:99999}));
});
