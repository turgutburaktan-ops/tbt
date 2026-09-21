const {readFileSync}=require('node:fs');
const {test,before,after,beforeEach}=require('node:test');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,serverTimestamp,Timestamp}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-tbt-route',firestore:{rules:readFileSync('firestore.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
beforeEach(async()=>{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx=>{
    const db=ctx.firestore();
    await setDoc(doc(db,'travel_plans/r'),{ownerId:'owner',memberIds:['owner','member'],visibility:'private'});
    for(const [id,data] of Object.entries({single:{},multi:{allowMultiple:true},closed:{closed:true},expired:{closesAt:Timestamp.fromMillis(1000)}})) {
      await setDoc(doc(db,`travel_plans/r/polls/${id}`),{authorId:'owner',question:'Hangisi?',options:['A','B'],closed:false,...data});
    }
  });
});
const db=uid=>env.authenticatedContext(uid).firestore();
const vote=(user,poll,data)=>setDoc(doc(db(user),`travel_plans/r/polls/${poll}/votes/${user}`),{...data,updatedAt:serverTimestamp()});
test('members keep legacy single votes; non-members cannot vote',async()=>{
  await assertSucceeds(vote('member','single',{choice:1}));
  await assertFails(vote('outsider','single',{choice:0}));
});
test('multiple choice accepts valid subsets and rejects duplicates and out-of-range values',async()=>{
  await assertSucceeds(vote('member','multi',{choices:[0,1]}));
  await assertSucceeds(vote('member','multi',{choices:[]}));
  await assertFails(vote('member','multi',{choices:[0,0]}));
  await assertFails(vote('member','multi',{choices:[2]}));
  await assertFails(vote('member','single',{choices:[0,1]}));
});
test('closed and expired polls reject votes',async()=>{
  await assertFails(vote('member','closed',{choice:0}));
  await assertFails(vote('member','expired',{choice:0}));
});
test('poll creation enforces membership, authorship and future closing date',async()=>{
  const payload={authorId:'member',question:'Ne zaman?',options:['Bugün','Yarın'],allowMultiple:true,closed:false,createdAt:serverTimestamp(),closesAt:Timestamp.fromMillis(Date.now()+3600000)};
  await assertSucceeds(setDoc(doc(db('member'),'travel_plans/r/polls/new'),payload));
  await assertFails(setDoc(doc(db('outsider'),'travel_plans/r/polls/outsider'),{...payload,authorId:'outsider'}));
  await assertFails(setDoc(doc(db('member'),'travel_plans/r/polls/past'),{...payload,closesAt:Timestamp.fromMillis(1000)}));
});
