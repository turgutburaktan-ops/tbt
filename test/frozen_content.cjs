const {test,before,after}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,collection,query,where}=require('firebase/firestore');
let env;
const types={stories:{userId:'u'},social_events:{hostId:'u',visibility:'public',participantIds:['u']},event_memories:{userId:'u',eventId:'visible'},communities:{ownerId:'u'},travel_plans:{ownerId:'u',memberIds:['u'],isPublic:true},post_reposts:{userId:'u',postId:'p'}};
const children={stories:['interactions/u'],social_events:['chat/m','attendance/u','info/main','likes/u','comments/c','tags/u'],event_memories:['likes/u','comments/c','tags/u'],communities:['followers/u'],travel_plans:['album/a','polls/p','polls/p/votes/u','messages/m','proposals/p','live_states/u','join_requests/u','ratings/u']};
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-tbt-frozen-content',firestore:{rules:fs.readFileSync('firestore.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();await setDoc(doc(db,'users/u'),{accountStatus:'active'});
  for(const [type,data] of Object.entries(types))for(const [id,frozen] of [['visible',false],['frozen',true]]){
   await setDoc(doc(db,type,id),{...data,accountFrozen:frozen});
   for(const child of children[type]||[])await setDoc(doc(db,`${type}/${id}/${child}`),{userId:'u',text:'synthetic'});
  }
 });
});
after(async()=>env?.cleanup());
test('frozen roots and nested content deny owner, outsider and anonymous reads',async()=>{
 for(const context of [env.authenticatedContext('u'),env.authenticatedContext('other'),env.unauthenticatedContext()]){
  const db=context.firestore();
  for(const type of Object.keys(types)){
   await assertFails(getDoc(doc(db,type,'frozen')));
   for(const child of children[type]||[])await assertFails(getDoc(doc(db,`${type}/frozen/${child}`)));
  }
 }
});
test('visible content keeps audience restrictions; queries must constrain visibility',async()=>{
 const db=env.authenticatedContext('u').firestore();
 for(const type of Object.keys(types))await assertSucceeds(getDoc(doc(db,type,'visible')));
 for(const type of ['stories','communities','post_reposts']) {
  await assertSucceeds(getDocs(query(collection(db,type),where('accountFrozen','==',false))));
  await assertFails(getDocs(collection(db,type)));
 }
 for(const [type,field,value] of [['social_events','visibility','public'],['travel_plans','isPublic',true]]) {
  await assertSucceeds(getDocs(query(collection(db,type),where('accountFrozen','==',false),where(field,'==',value))));
  await assertFails(getDocs(query(collection(db,type),where(field,'==',value))));
 }
});
