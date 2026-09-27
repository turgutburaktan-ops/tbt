const test=require('node:test'),assert=require('node:assert/strict');
const {duplicate,indexRows,validate}=require('./cafe_expansion');
const {venueRow}=require('./schema');
const row={venueId:'overture-12345678-abcd',venueName:'Çınar Kafe',city:'Elazığ',category:'cafe',
  latitude:38.6748,longitude:39.2225,status:'published',source:'overture',sourceConfidence:.95};
test('provider validation and attribution are preserved without granting ownership',()=>{
  assert.ok(validate(row));assert.ok(!validate({...row,sourceConfidence:.4}));
  assert.ok(!validate({...row,city:'Unknown'}));assert.ok(!validate({...row,latitude:0}));
  const result=venueRow(`cafe:${row.venueId}`,row,null);
  assert.equal(result.source,'overture');assert.equal(result.managed,false);
  assert.match(result.attribution,/Overture/);
});
test('same business across providers is skipped but remote branches remain',()=>{
  assert.ok(duplicate(row,{...row,venueName:'Çınar Cafe',latitude:38.675}));
  assert.ok(!duplicate(row,{...row,latitude:38.69}));
  assert.ok(!duplicate(row,{...row,venueName:'Başka Kafe'}));
  const idx=indexRows([{...row,latitude:38.67399}]);
  assert.ok(idx.has({...row,latitude:38.67401}));
  assert.ok(!idx.has({...row,latitude:39}));
});
