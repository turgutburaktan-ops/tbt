const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const path = require('node:path');
const {DAY, WEIGHTS, calculate, lifecycle, validScores} = require('../venue_quality_policy');
const now = 1800000000000;
const scores = n => Object.fromEntries(['quality', 'cleanliness', 'service', 'value', 'comfort'].map(k => [k, n]));
function reviews(count, span, value = 5) {
  return Array.from({length: count}, (_, i) => ({userId: `u${i}`, scores: scores(value), proof: {type: 'coupon', at: now - (i < 5 ? i : span * i / (count - 1)) * DAY}, updatedAt: now}));
}
test('category weights sum to 100, hotel/cafe/restaurant use their own weights', () => {
  for (const weights of Object.values(WEIGHTS)) assert.equal(weights.reduce((a,b) => a+b), 100);
  const row = reviews(1, 0)[0]; row.scores.quality = 1;
  assert.equal(calculate('dining', [row], now).score, 72);
  assert.equal(calculate('cafe', [row], now).score, 76);
  assert.equal(calculate('hotel', [row], now).score, 76);
});
test('criteria require exactly five integer values within 1–5', () => {
  assert.ok(validScores(scores(3)));
  assert.ok(!validScores({...scores(3), quality: 5.1}));
  assert.ok(!validScores({...scores(3), bonus: 5}));
  assert.ok(!validScores({quality: 5}));
});
test('all three thresholds require score, distinct people and observation span', () => {
  assert.equal(calculate('dining', reviews(14, 30), now).candidate, 0);
  assert.equal(calculate('dining', reviews(15, 29), now).candidate, 0);
  assert.equal(calculate('dining', reviews(15, 30, 4), now).candidate, 1);
  assert.equal(calculate('dining', reviews(40, 90), now).candidate, 2);
  assert.equal(calculate('hotel', reviews(80, 180), now).candidate, 3);
});
test('poor cleanliness cannot be compensated by other criteria', () => {
  const rows = reviews(80, 180); rows.forEach(r => r.scores.cleanliness = 3);
  assert.equal(calculate('dining', rows, now).candidate, 0);
});
test('criterion floors prevent top-tier awards despite high overall scores', () => {
  const rows = reviews(80, 180); rows.forEach(r => r.scores.comfort = 4);
  assert.equal(calculate('dining', rows, now).candidate, 2);
  rows.forEach(r => r.scores.comfort = 3);
  assert.equal(calculate('dining', rows, now).candidate, 1);
});
test('recent period gets 60%, older period 40%, a sole period gets 100%', () => {
  const r = reviews(1, 0, 5)[0], o = {...reviews(1,0,1)[0], userId: 'older', proof: {type: 'qr', at: now-100*DAY}};
  assert.equal(calculate('cafe', [r, o], now).score, 68);
  assert.equal(calculate('cafe', [o], now).score, 20);
});
test('old edits do not renew visits; stale, unverified, excluded and duplicate rows do not inflate counts', () => {
  const rows = reviews(15, 30);
  rows.push({...rows[0], updatedAt: now + 1});
  rows.push({...rows[0], userId: 'excluded', excluded: true});
  rows.push({...rows[0], userId: 'old', proof: {type:'coupon', at: now-366*DAY}});
  rows.push({...rows[0], userId: 'fake', proof: {type:'photo', at: now}});
  assert.equal(calculate('dining', rows, now).count, 15);
  assert.equal(calculate('dining', reviews(80,180).map(r => ({...r, proof:{type:'qr',at:now-100*DAY},updatedAt:now})), now).candidate, 0);
});
test('below-threshold review opens after 30 days and resets on recovery', () => {
  const state = lifecycle({award:2}, {candidate:1}, now);
  assert.equal(state.needsReview, false);
  assert.equal(lifecycle(state, {candidate:1}, now+30*DAY).needsReview, true);
  assert.equal(lifecycle(state, {candidate:2}, now+30*DAY).belowSinceMs, 0);
});

// Transactional callable harness: all reads must precede writes; failed transactions
// discard pending writes. Authorization, source checks and publication use real handlers.
function harness() {
  const records = new Map(); let serial = 0;
  const timestamp = {fromMillis: n => ({toMillis: () => n}), now: () => timestamp.fromMillis(Date.now())};
  const ref = p => ({path:p, id:p.split('/').at(-1), collection: n => query(`${p}/${n}`),
    get: async () => snap(p), set: async (d,o) => { records.set(p,o?.merge?{...records.get(p),...d}:d); },
    delete: async () => records.delete(p)});
  const snap = p => ({id:p.split('/').at(-1), ref:ref(p), exists:records.has(p), data:()=>records.get(p)});
  function query(p, filters=[], maximum=Infinity, after=null) {
    const q = {path:p, doc: id=>ref(`${p}/${id||`auto${++serial}`}`),
      where:(field,op,value)=>query(p,[...filters,[field,value]],maximum,after),
      orderBy:()=>q, limit:n=>query(p,filters,n,after), startAfter:id=>query(p,filters,maximum,id),
      get: async () => {
        const docs=[...records.keys()].filter(k=>k.startsWith(p+'/')&&k.slice(p.length+1).indexOf('/')<0).sort()
          .filter(k=>!after||k.split('/').at(-1)>after).filter(k=>filters.every(([f,v])=>records.get(k)[f]===v)).slice(0,maximum).map(snap);
        return {docs,size:docs.length,empty:!docs.length};
      }};
    return q;
  }
  const db={doc:ref,collection:query,runTransaction:async fn=>{
    const writes=[];
    const tx={get:async r=>{assert.equal(writes.length,0,'read after write');return r.get();},getAll:async(...refs)=>Promise.all(refs.map(r=>tx.get(r))),
      set:(r,d,o)=>writes.push(()=>records.set(r.path,o?.merge?{...records.get(r.path),...d}:d)),
      update:(r,d)=>writes.push(()=>records.set(r.path,{...records.get(r.path),...d})),
      create:(r,d)=>writes.push(()=>records.set(r.path,d))};
    const result=await fn(tx); writes.forEach(w=>w());return result;
  }};
  const filename=path.join(__dirname,'../venue_quality.js'), loaded=new Module(filename,module);
  loaded.filename=filename;loaded.paths=module.paths;
  loaded.require=id=>id==='firebase-functions/v2/https'?{onCall:(_,fn)=>fn,HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}}}
    :id==='firebase-functions/v2/firestore'?{onDocumentWritten:(_,fn)=>fn}
    :id==='firebase-functions/v2/scheduler'?{onSchedule:(_,fn)=>fn}
    :id==='firebase-admin/firestore'?{getFirestore:()=>db,Timestamp:timestamp,FieldPath:{documentId:()=> '__name__'}}
    :id==='./broadcast_policy'?{isNamedAdmin:a=>a?.uid==='admin'&&a?.token?.admin===true}
    :id==='./venue_quality_policy'?require('../venue_quality_policy'):require(id);
  loaded._compile(fs.readFileSync(filename,'utf8'),filename);
  const key='dining:test';
  records.set(`business_venues/${key}`,{ownerUid:'owner',verified:true,name:'Test Mekân'});
  const call=(uid,action,data={})=>loaded.exports.venueQuality({auth:uid?{uid,token:{email:`${uid}@example.com`,admin:uid==='admin'}}:null,data:{action,venueKey:key,...data}});
  const coupon=uid=>records.set(`business_venues/${key}/coupon_claims/${uid}`,{userUid:uid,status:'used',validatedBy:'owner',usedAt:timestamp.now()});
  return {records,call,key,coupon};
}
test('anonymous/admin spoofing and unverified submissions are rejected', async () => {
  const h=harness();
  await assert.rejects(h.call(null,'status'),{code:'unauthenticated'});
  await assert.rejects(h.call('user','adminList'),{code:'permission-denied'});
  await assert.rejects(h.call('user','submit',{scores:scores(5),proof:{type:'coupon',at:Date.now()}}),{code:'failed-precondition'});
});
test('prepared or future reservations are not proof of a completed visit', async () => {
  const h=harness(), p=`business_venues/${h.key}/reservations/r`;
  h.records.set(p,{userUid:'user',status:'accepted',preparationStatus:'preparing',preparationStartedAt:Date.now()-1000,at:Date.now()-1000});
  assert.equal((await h.call('user','status')).eligible,false);
  h.records.set(p,{...h.records.get(p),preparationStatus:'completed',at:Date.now()+DAY});
  assert.equal((await h.call('user','status')).eligible,false);
  h.records.set(p,{...h.records.get(p),at:Date.now()-1000});
  assert.equal((await h.call('user','status')).eligible,true);
});
test('owners and registered staff cannot rate their own venue', async () => {
  const h=harness(); h.coupon('owner');h.coupon('staff');
  h.records.set(`business_venues/${h.key}/staff/staff`,{email:'staff@example.com',active:true});
  assert.equal((await h.call('owner','status')).eligible,false);
  assert.equal((await h.call('staff','status')).eligible,false);
  await assert.rejects(h.call('owner','submit',{scores:scores(5)}),{code:'failed-precondition'});
});
test('visit codes require ownership, are single-use and replacement invalidates old code', async () => {
  const h=harness();
  await assert.rejects(h.call('user','createVisit'),{code:'permission-denied'});
  const old=await h.call('owner','createVisit'), code=await h.call('owner','createVisit');
  await assert.rejects(h.call('user','redeemVisit',{token:old.token}),{code:'failed-precondition'});
  await h.call('user','redeemVisit',{token:code.token});
  await assert.rejects(h.call('other','redeemVisit',{token:code.token}),{code:'failed-precondition'});
  assert.equal((await h.call('user','status')).eligible,true);
});
test('only verified reviews enter public aggregates; reviewer information remains private', async () => {
  const h=harness(); h.coupon('user');
  await h.call('user','submit',{scores:scores(4)});
  const data=h.records.get(`venue_quality_public/${h.key}`);
  assert.equal(data.score,80); assert.equal(data.count,1); assert.equal(data.award,0);
  assert.equal(data.email,undefined); assert.equal(data.proof,undefined);
  await assert.rejects(h.call('admin','decide',{decision:'approve',reason:'Yeterli kalite var'}),{code:'failed-precondition'});
});
test('deleted or revoked proof is removed from recalculation', async () => {
  const h=harness(); h.coupon('user'); await h.call('user','submit',{scores:scores(5)});
  h.records.delete(`business_venues/${h.key}/coupon_claims/user`);
  await h.call('admin','adminDetail');
  assert.equal(h.records.get(`venue_quality_public/${h.key}`).count,0);
});
test('moderation cannot be bypassed by deleting and resubmitting a review', async () => {
  const h=harness(); h.coupon('user'); await h.call('user','submit',{scores:scores(5)});
  await h.call('admin','moderate',{reviewUid:'user',excluded:true,reason:'Doğrulanan sahte deneyim'});
  await h.call('user','delete');
  await assert.rejects(h.call('user','submit',{scores:scores(5)}),{code:'failed-precondition'});
});
test('qualified candidates require admin approval, complaints do not remove awards, suspension hides award', async () => {
  const h=harness();
  for(let i=0;i<15;i++) {
    const uid=`visitor${i}`, at=Date.now()-i/14*31*DAY;
    h.records.set(`business_venues/${h.key}/coupon_claims/${uid}`,{userUid:uid,status:'used',validatedBy:'owner',usedAt:at});
    await h.call(uid,'submit',{scores:scores(4)});
  }
  assert.equal(h.records.get(`venue_quality/${h.key}`).candidate,1);
  assert.equal(h.records.get(`venue_quality_public/${h.key}`).award,0);
  await h.call('admin','decide',{decision:'approve',reason:'Doğrulanmış deneyimler incelendi'});
  assert.equal(h.records.get(`venue_quality_public/${h.key}`).award,1);
  await h.call('visitor0','report',{reason:'Ziyaret sırasında bir sorun yaşandı'});
  assert.equal(h.records.get(`venue_quality_public/${h.key}`).award,1);
  await h.call('admin','decide',{decision:'suspend',reason:'Ciddi sorun belgelerle doğrulandı'});
  assert.equal(h.records.get(`venue_quality_public/${h.key}`).award,0);
  assert.equal(h.records.get(`venue_quality_public/${h.key}`).suspended,true);
  assert.equal([...h.records.keys()].filter(k=>k.includes('/decisions/')).length,2);
});
