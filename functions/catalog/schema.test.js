const test = require('node:test');
const assert = require('node:assert/strict');
const {provinces, partition, spotRow, venueRow} = require('./schema');
const {decode, query} = require('./importer');
const external = {venueId:'node-123',venueName:'Bir Kafe',category:'cafe',city:'Elazığ',latitude:38.67,longitude:39.22,status:'published'};
test('81 provinces have stable unique partitions, including Turkish characters',()=>{
  assert.equal(new Set(provinces.map(c=>partition(c,'cafe'))).size,81);
  assert.equal(partition('İSTANBUL','cafe'),'istanbul_cafe');
  assert.equal(partition('Elazig','cafe'),'elazig_cafe');
  assert.equal(partition('bilinmeyen','cafe'),null);
});
test('claim projection preserves external identity and fills incomplete approved metadata',()=>{
  const d=venueRow('cafe:node-123',external,{verified:true,category:'cafe',venueName:'Yeni Ad',ownerUid:'secret',taxNumber:'private'});
  assert.equal(d.canonicalId,'venue:cafe:node-123');assert.equal(d.legacyId,'node-123');
  assert.equal(d.city,'Elazığ');assert.equal(d.name,'Yeni Ad');assert.equal(d.managed,true);
  assert.equal(d.ownerUid,undefined);assert.equal(d.taxNumber,undefined);
  assert.equal(venueRow('cafe:node-123',null,{...external,verified:false}),null);
  assert.equal(venueRow('cafe:node-123',external,null,true),null);
});
test('only reviewed published gezi records enter public catalog, preserving IDs',()=>{
  const d={name:'Kale',city:'Elazığ',latitude:38.7,longitude:39.2,status:'published',coordinateVerified:true,imageVerified:true,imageUrl:'https://example.org/photo.jpg',ownerUid:'private'};
  assert.equal(spotRow('original',d).legacyId,'original');
  assert.equal(spotRow('original',d).ownerUid,undefined);
  for(const patch of [{status:'pending'},{coordinateVerified:false},{imageVerified:false},{latitude:0}])assert.equal(spotRow('original',{...d,...patch}),null);
});
test('imports reject incomplete results and preserve source IDs without importing unlicensed photos',()=>{
  assert.throws(()=>decode({elements:[]},'Elazığ','cafe'));
  assert.throws(()=>decode({remark:'timeout',elements:[{type:'area'}]},'Elazığ','cafe'));
  const rows=decode({elements:[{type:'area'},{type:'node',id:123,lat:38.67,lon:39.22,tags:{name:'Kafe',image:'https://example.org/unlicensed.jpg'}}]},'Elazığ','cafe');
  assert.equal(rows[0].venueId,'node-123');assert.equal(rows[0].imageUrl,undefined);
  assert.match(query('Elazığ','cafe'),/TR-23/);
  assert.match(query('Düzce','hotel'),/TR-81/);
});
test('country-sized imports preserve identities and nearby duplicates without quadratic name scans',{timeout:10000},()=>{
  const elements=Array.from({length:10000},(_,i)=>({type:'node',id:i+1,lat:38.67,lon:39.22,tags:{name:`Mekân ${i}`}}));
  const duplicates=elements.slice(0,1000).map(e=>({...e,id:e.id+10000}));
  const rows=decode({elements:[{type:'area'},...elements,...duplicates]},'Elazığ','cafe');
  assert.equal(rows.length,10000);assert.equal(rows[0].venueId,'node-1');assert.equal(rows.at(-1).venueId,'node-10000');
});
