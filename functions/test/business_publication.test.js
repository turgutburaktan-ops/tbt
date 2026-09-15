const test = require('node:test');
const assert = require('node:assert/strict');
const {publicationData, publishApprovedCandidate} = require('../business_publication');
const claim = {venueId:'user_abc',category:'dining',applicantUid:'owner',venueName:'burak',status:'verified'};
const submission = {venueId:'user_abc',category:'dining',createdBy:'owner',venueName:'burak',latitude:38.67,longitude:39.22,city:'Elazığ',address:'Test adres'};
test('restores missing listing data from original approved submission',()=>{
  const p=publicationData(claim,{verified:true},submission,'now');
  assert.equal(p.latitude,38.67);assert.equal(p.city,'Elazığ');assert.equal(p.source,'user_submission');
  assert.equal(p.pendingListing,false);assert.equal(p.listingStatus,'published');
});
test('retains existing edited address and coordinates',()=>{
  const p=publicationData(claim,{latitude:38.7,longitude:39.3,address:'Updated',publishedAt:'earlier'},submission,'now');
  assert.equal(p.latitude,38.7);assert.equal(p.address,'Updated');assert.equal(p.publishedAt,'earlier');
});
test('never publishes missing or mismatched submissions or invalid locations',()=>{
  for(const s of [null,{...submission,createdBy:'other'},{...submission,category:'hotel'},{...submission,latitude:null}])
    assert.throws(()=>publicationData(claim,{},s,'now'));
});
test('late approval event cannot publish a currently rejected claim',async()=>{
  const writes=[];const db={collection:c=>({doc:id=>({path:c+'/'+id})}),runTransaction:fn=>fn({get:async()=>({data:()=>({...claim,status:'rejected'})}),set:(...args)=>writes.push(args)})};
  const result=await publishApprovedCandidate(db,'dining:user_abc','now');assert.equal(result.repaired,false);assert.equal(writes.length,0);
});
test('approved listing and submission are written in the same transaction',async()=>{
  const writes=[];const db={collection:c=>({doc:id=>({path:c+'/'+id})}),runTransaction:fn=>fn({
    get:async ref=>({data:()=>ref.path.startsWith('business_claims/')?claim:ref.path.startsWith('business_venue_submissions/')?submission:{verified:true}}),
    set:(ref,data)=>writes.push({path:ref.path,data}),
  })};
  const result=await publishApprovedCandidate(db,'dining:user_abc','now');assert.equal(result.repaired,true);assert.equal(writes.length,2);
  assert.equal(writes[0].data.latitude,38.67);assert.equal(writes[1].data.status,'published');
});
