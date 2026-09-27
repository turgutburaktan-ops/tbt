const test=require('node:test'),assert=require('node:assert/strict'),Module=require('node:module'),fs=require('node:fs'),path=require('node:path');
const {MINUTE}=require('../reservation_policy');
class Ts{constructor(value){this.value=value;}toMillis(){return this.value;}static now(){return new Ts(Date.now());}static fromMillis(value){return new Ts(value);}}
function harness(){
 const records=new Map(),writes=[];
 function ref(p){return {path:p,id:p.split('/').at(-1),parent:{id:p.split('/').at(-2),parent:p.split('/').length>2?ref(p.split('/').slice(0,-2).join('/')):null},collection:name=>({doc:id=>ref(p+'/'+name+'/'+id)})};}
 const db={doc:ref,collection:name=>({doc:id=>ref(name+'/'+id)}),runTransaction:async fn=>{
  let writing=false;
  const tx={get:async r=>{assert.equal(writing,false,'all reads must precede writes');return {exists:records.has(r.path),data:()=>records.get(r.path),ref:r};},set:(r,d,options)=>{writing=true;records.set(r.path,options?.merge?{...records.get(r.path),...d}:d);writes.push(r.path);},create:(r,d)=>{assert.ok(!records.has(r.path));tx.set(r,d);},update:(r,d)=>{assert.ok(records.has(r.path));tx.set(r,d,{merge:true});},delete:r=>{writing=true;records.delete(r.path);}};return fn(tx);
 }};
 const loaded=new Module(__filename);
 const reminders=new Module(__filename);
 loaded.require=id=>id==='firebase-functions/v2/https'?{onCall:(_,handler)=>handler,HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}}}:id==='firebase-functions/v2/firestore'?{onDocumentWritten:(_,handler)=>handler}:id==='firebase-functions/v2/scheduler'?{onSchedule:(_,handler)=>handler}:id==='firebase-admin/firestore'?{getFirestore:()=>db,Timestamp:Ts,FieldValue:{serverTimestamp:()=>Ts.now()}}:id==='./reservation_policy'?require('../reservation_policy'):id==='./reservation_reminders'?reminders.exports:require(id);
 reminders.require=loaded.require;
 reminders._compile(fs.readFileSync(path.join(__dirname,'../reservation_reminders.js'),'utf8'),path.join(__dirname,'../reservation_reminders.js'));
 loaded._compile(fs.readFileSync(path.join(__dirname,'../reservation_preparation.js'),'utf8'),path.join(__dirname,'../reservation_preparation.js'));
 const reservation=ref('business_venues/dining:test/reservations/test');
 records.set('business_venues/dining:test',{verified:true,ownerUid:'owner',venueName:'Test'});
 const at=Date.now()+10*MINUTE;records.set(reservation.path,{userUid:'customer',status:'accepted',at:Ts.fromMillis(at),orderItems:[{}],preparationStatus:'awaiting_confirmation'});
 return {records,writes,reservation,api:loaded.exports,at,call:(uid,action,extra={})=>loaded.exports.reservationPreparationAction({auth:{uid},data:{venueKey:'dining:test',reservationId:'test',expectedAtMs:at,action,...extra}})};
}
test('duplicate reminder events create one notification and cancellation prevents sending',async()=>{
 const h=harness(),event={data:{after:{ref:h.reservation}}};await h.api.syncBusinessPreparationReminder(event);await h.api.syncBusinessPreparationReminder(event);
 assert.equal([...h.records.keys()].filter(k=>k.includes('/notifications/')).length,1);
 const other=harness();other.records.get(other.reservation.path).status='cancelled';await other.api.syncBusinessPreparationReminder({data:{after:{ref:other.reservation}}});assert.equal([...other.records.keys()].filter(k=>k.includes('/notifications/')).length,0);
});
test('future reminders are queued and stale events use the current reservation time',async()=>{
 const h=harness();h.records.get(h.reservation.path).at=Ts.fromMillis(Date.now()+60*MINUTE);
 await h.api.syncBusinessPreparationReminder({data:{after:{ref:h.reservation}}});
 assert.equal([...h.records.keys()].filter(k=>k.startsWith('reservation_preparation_jobs/')).length,1);
 assert.equal([...h.records.keys()].filter(k=>k.includes('/notifications/')).length,0);
});
test('preparation cannot be forged by another user or started without customer consent',async()=>{
 const h=harness();await assert.rejects(()=>h.call('intruder','confirm'),/yetkin yok/);await assert.rejects(()=>h.call('owner','start'),/müşterinin/);assert.equal(h.writes.length,0);
 await h.call('customer','confirm');await h.call('owner','start');await h.call('owner','start');
 assert.equal([...h.records.keys()].filter(k=>k.includes('/reservation_history/')).length,1);
 await h.call('customer','cancel');const history=[...h.records.entries()].find(([p])=>p.includes('/reservation_history/'))[1];assert.equal(history.status,'cancelled');
 await h.call('customer','dispute',{reason:'Hazırlık başlamamıştı'});assert.equal([...h.records.entries()].find(([p])=>p.includes('/reservation_history/'))[1].status,'disputed');
});
test('stale time confirmation is rejected and only named admin can review disputes',async()=>{
 const h=harness();await assert.rejects(()=>h.call('customer','confirm',{expectedAtMs:h.at-1}),/saati değişti/);
 await assert.rejects(()=>h.api.getReservationDisputes({auth:{uid:'owner',token:{}}}),/Yönetici/);
});
