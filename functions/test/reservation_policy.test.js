const test=require('node:test'),assert=require('node:assert/strict');
const {transition,historySummary,MINUTE,DAY}=require('../reservation_policy');
const now=Date.now();const r=()=>({status:'accepted',at:now+10*MINUTE,orderItems:[{quantity:1}],preparationStatus:'awaiting_confirmation'});
test('customer confirmation is required before preparation and only opens 15 minutes before',()=>{
 assert.throws(()=>transition(r(),'start','owner',now),/müşterinin/);
 assert.throws(()=>transition({...r(),at:now+16*MINUTE},'confirm','customer',now),/15 dakika/);
 const confirmed={...r(),...transition(r(),'confirm','customer',now).patch};
 const started={...confirmed,...transition(confirmed,'start','owner',now).patch};
 assert.equal(started.preparationStatus,'preparing');
 assert.equal(transition(started,'start','owner',now).noop,true);
 assert.equal(transition(confirmed,'confirm','customer',now).noop,true);
});
test('an owner cannot confirm for customer and a customer cannot mark a no-show',()=>{
 assert.throws(()=>transition(r(),'confirm','owner',now));assert.throws(()=>transition(r(),'no_show','customer',now));
});
test('cancellation before preparation does not count; after preparation counts separately',()=>{
 assert.equal(transition(r(),'cancel','customer',now).outcome,null);
 const started={...r(),preparationConfirmedAt:now-2000,preparationStartedAt:now-1000,preparationStatus:'preparing'};
 assert.equal(transition(started,'cancel','customer',now).outcome,'cancelled');
 assert.throws(()=>transition({...started,status:'cancelled'},'start','owner',now));
});
test('rescheduling clears confirmation and requires business acceptance again',()=>{
 const result=transition({...r(),preparationConfirmedAt:now,preparationStatus:'confirmed'},'reschedule','customer',now,now+DAY);
 assert.equal(result.patch.status,'pending');assert.equal(result.patch.preparationConfirmedAt,null);assert.equal(result.patch.scheduleVersion,1);
 assert.throws(()=>transition({...r(),preparationStartedAt:now},'reschedule','customer',now,now+DAY));
});
test('no-show requires actual preparation, grace time, and an unresolved order',()=>{
 const prepared={...r(),at:now-31*MINUTE,preparationConfirmedAt:now-45*MINUTE,preparationStartedAt:now-40*MINUTE,preparationStatus:'preparing'};
 const result=transition(prepared,'no_show','owner',now);assert.equal(result.outcome,'reported');assert.equal(result.patch.incidentReviewAfter,now+3*DAY);
 assert.throws(()=>transition({...prepared,at:now-29*MINUTE},'no_show','owner',now));
 assert.throws(()=>transition({...prepared,preparationStatus:'completed'},'no_show','owner',now));
 assert.throws(()=>transition({...prepared,preparationStartedAt:null},'no_show','owner',now));
});
test('90-day history excludes disputed, dismissed and unexpired reports from adverse counts',()=>{
 const rows=[{preparedAt:now-91*DAY,status:'cancelled'},{preparedAt:now-DAY,status:'cancelled'},{preparedAt:now-DAY,status:'completed'},{preparedAt:now-5*DAY,status:'reported',reviewAfter:now-1},{preparedAt:now-DAY,status:'reported',reviewAfter:now+DAY},{preparedAt:now-DAY,status:'disputed'},{preparedAt:now-DAY,status:'dismissed'},{preparedAt:now-DAY,status:'confirmed_no_show'}];
 assert.deepEqual(historySummary(rows,now),{prepared:7,cancelled:1,noShows:2});
});
