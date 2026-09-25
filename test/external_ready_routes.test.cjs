const {test}=require('node:test');
const assert=require('node:assert/strict');
const {validate}=require('../functions/scripts/publish_elazig_external_routes.cjs');
const routes=require('../functions/scripts/elazig_external_routes.json');
test('all four source tracks fit the mobile snapshot and geometry contract',()=>validate(routes));
test('reject invalid coordinates, stale geometry signatures and duplicate reserved IDs',()=>{
  for(const mutate of [r=>r[0].dayPlan.geometry[0].lat=0,
    r=>r[0].stopSnapshots[0].latitude+=0.01,
    r=>r[1].id=r[0].id,
    r=>r[0].dayPlan.legs[0].meters=NaN]){
    const changed=structuredClone(routes);mutate(changed);assert.throws(()=>validate(changed));
  }
});
test('Cip return follows the outbound track exactly and discloses reconstruction',()=>{
  const r=routes.find(r=>r.id.includes('cip_')), g=r.dayPlan.geometry;
  assert.equal(r.externalSource.returnTrackMirrored,true);
  assert.equal(g.length,r.externalSource.trackPointCount*2-1);
  for(let i=0;i<g.length;i++)assert.deepEqual(g[i],g[g.length-1-i]);
  assert.equal(r.stopSnapshots.length,3);
  assert(r.dayPlan.description.includes('KML yalnızca gidişi içerir'));
});
