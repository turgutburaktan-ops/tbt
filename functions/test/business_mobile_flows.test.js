const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
function harness(file,seed={}){
  const rows=new Map(Object.entries(seed)),writes=[];
  const ref=p=>({path:p,collection:n=>({doc:id=>ref(p+'/'+n+'/'+id)})});
  const db={doc:ref,runTransaction:async fn=>{
    const pending=[];
    const result=await fn({get:async r=>({exists:rows.has(r.path),data:()=>rows.get(r.path)}),
      create:(r,d)=>pending.push(['create',r.path,d]),update:(r,d)=>pending.push(['update',r.path,d]),delete:r=>pending.push(['delete',r.path])});
    for(const [op,p,d] of pending){if(op==='delete')rows.delete(p);else rows.set(p,{...rows.get(p),...d});writes.push([op,p,d]);}return result;
  }};
  class HttpsError extends Error{constructor(code,message){super(message);this.code=code;}}
  const context={exports:{},require:name=>name==='firebase-functions/v2/https'?{onCall:(_,fn)=>fn,HttpsError}:name==='firebase-admin/firestore'?{getFirestore:()=>db,Timestamp:{fromMillis:v=>v},FieldValue:{serverTimestamp:()=>123,arrayRemove:v=>({remove:v})},GeoPoint:class{constructor(lat,lng){this.lat=lat;this.lng=lng;}}}:require(name)};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname,'..',file),'utf8'),context);
  return {api:context.exports,rows,writes};
}
const input={venueKey:'cafe:node-1',requestId:'request-123456789',title:'Sabah koşusu',type:'running',city:'Elazığ',locationLabel:'Kafe',description:'Birlikte koşuyoruz',startsAtMs:Date.now()+86400000,capacity:20,latitude:38.7,longitude:39.2};
test('business event requires authenticated verified ownership',async()=>{
  const h=harness('business_events.js');
  await assert.rejects(h.api.createBusinessEvent({data:input}),e=>e.code==='unauthenticated');
  await assert.rejects(h.api.createBusinessEvent({auth:{uid:'other'},data:input}),e=>e.code==='permission-denied');
  assert.equal(h.writes.length,0);
});
test('one business event and program share identity, retries never duplicate or reset participants',async()=>{
  const h=harness('business_events.js',{'business_venues/cafe:node-1':{verified:true,ownerUid:'owner',venueName:'Kafe'}});
  const request={auth:{uid:'owner'},data:input},r=await h.api.createBusinessEvent(request),event=h.rows.get('social_events/'+r.eventId);
  assert.equal(event.hostName,'Kafe');assert.equal(event.hostId,'owner');assert.equal(event.visibility,'public');assert.equal(event.type,'running');
  assert.equal(h.rows.get('business_venues/cafe:node-1/program/'+r.eventId).socialEventId,r.eventId);
  event.participantIds.push('guest');assert.equal((await h.api.createBusinessEvent(request)).eventId,r.eventId);
  assert.equal(h.writes.length,2);assert.equal(event.participantIds.length,2);
});
test('invalid business event cannot publish either copy',async()=>{
  const h=harness('business_events.js',{'business_venues/cafe:node-1':{verified:true,ownerUid:'owner'}});
  for(const patch of [{capacity:0},{latitude:200},{startsAtMs:0},{type:'forged'}])await assert.rejects(h.api.createBusinessEvent({auth:{uid:'owner'},data:{...input,...patch}}),e=>e.code==='invalid-argument');
  assert.equal(h.writes.length,0);
});
test('member leaves only their own membership; owner cannot leave or remove others',async()=>{
  const h=harness('route_membership.js',{'travel_plans/route':{ownerId:'owner',memberIds:['owner','member']},'travel_plans/route/members/member':{uid:'member'}});
  await assert.rejects(h.api.leaveTravelPlan({auth:{uid:'owner'},data:{planId:'route'}}),e=>e.code==='failed-precondition');
  await h.api.leaveTravelPlan({auth:{uid:'outsider'},data:{planId:'route',uid:'member'}});assert.equal(h.writes.length,0);
  await h.api.leaveTravelPlan({auth:{uid:'member'},data:{planId:'route',uid:'owner'}});
  assert.equal(h.rows.get('travel_plans/route').memberIds.remove,'member');assert.equal(h.rows.has('travel_plans/route/members/member'),false);
});
