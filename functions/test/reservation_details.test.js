const test=require('node:test'),assert=require('node:assert/strict');
const Module=require('node:module'),fs=require('node:fs'),path=require('node:path');
const loaded=new Module(__filename);
loaded.require=id=>id==='firebase-functions/v2/https'?{HttpsError:class extends Error{constructor(code,message){super(message);this.code=code;}}}:require(id);
loaded._compile(fs.readFileSync(path.join(__dirname,'../reservation_details.js'),'utf8'),path.join(__dirname,'../reservation_details.js'));
const {orderSelection,pricedOrder,reservationView}=loaded.exports;
const doc=d=>({exists:true,data:()=>d});
test('orders use menu prices, not prices supplied by customer',()=>{
 const selection=orderSelection([{itemId:'coffee',quantity:2,unitPriceMinor:1}]);
 const result=pricedOrder(selection,[doc({name:'Coffee',priceMinor:8500})]);
 assert.equal(result[0].totalMinor,17000);
});
test('invalid quantities, duplicate ids and unavailable menu items are rejected',()=>{
 for(const raw of [[{itemId:'x',quantity:-1}],[{itemId:'x',quantity:1.5}],[{itemId:'x',quantity:1},{itemId:'x',quantity:1}]])assert.throws(()=>orderSelection(raw));
 assert.throws(()=>pricedOrder([{itemId:'x',quantity:1}],[doc({available:false,priceMinor:1})]));
 assert.throws(()=>pricedOrder([{itemId:'x',quantity:1}],[doc({name:'Unpriced'})]));
});
test('legacy reservations recover the name without exposing profile contact details',()=>{
 const row=reservationView({id:'old',data:()=>({userUid:'u',status:'accepted',partySize:2,at:{toMillis:()=>123}})},'dining:v',{displayName:'Burak',phone:'private',email:'private'});
 assert.equal(row.customerName,'Burak');assert.equal(row.contactPhone,'');assert.equal(row.email,undefined);assert.equal(row.status,'accepted');assert.deepEqual(row.orderItems,[]);
});
test('price changes require a new customer review',()=>{
 assert.throws(()=>pricedOrder(orderSelection([{itemId:'x',quantity:1,expectedUnitPriceMinor:500}]),[doc({priceMinor:600})]),/fiyatı değişti/);
});
test('personal reservation query ignores requested identities and requires sign-in',async()=>{
 const calls=[];const query={where:(...args)=>{calls.push(args);return query;},orderBy:()=>query,limit:()=>query,get:async()=>({docs:[]})};
 const db={collectionGroup:name=>{assert.equal(name,'reservations');return query;}};
 const growth=new Module(__filename);
 growth.require=id=>id==='firebase-functions/v2/https'?{onCall:(_,handler)=>handler,HttpsError:class extends Error{}}:id==='firebase-admin/firestore'?{getFirestore:()=>db}:id==='./reservation_details'?loaded.exports:id==='./reservation_reminders'?{syncReminder:async()=>{}}:id==='./reservation_history'?{customerHistory:async()=>({prepared:0,cancelled:0,noShows:0})}:require(id);
 growth._compile(fs.readFileSync(path.join(__dirname,'../business_growth.js'),'utf8'),path.join(__dirname,'../business_growth.js'));
 await assert.rejects(()=>growth.exports.getMyBusinessReservations({data:{userUid:'someone-else'}}));assert.equal(calls.length,0);
 await growth.exports.getMyBusinessReservations({auth:{uid:'self'},data:{userUid:'someone-else'}});
 assert.deepEqual(calls,[['userUid','==','self']]);
});
