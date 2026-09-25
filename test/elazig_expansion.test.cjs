const test=require('node:test');
const assert=require('node:assert/strict');
const {validate}=require('../functions/scripts/publish_elazig_external_routes.cjs');
const routes=require('../functions/scripts/elazig_expansion_routes.json');
const photos=require('../functions/scripts/elazig_expansion_photos.json');
const previous=require('../functions/scripts/elazig_external_routes.json');
test('six additions have usable tracks, covers and no duplicate previous routes',()=>{
 assert.equal(routes.length,6); validate(routes);
 assert.deepEqual(photos.map(p=>p.id),routes.map(r=>r.id));
 assert.equal(new Set([...routes,...previous].map(r=>r.id)).size,routes.length+previous.length);
 assert.equal(new Set([...routes,...previous].map(r=>r.externalSource.sha256)).size,routes.length+previous.length);
 for(const r of routes) assert(Math.abs(r.distanceKm-r.externalSource.publishedDistanceKm)/r.externalSource.publishedDistanceKm<.1);
});
test('return tracks are disclosed and follow the downloaded outbound track backwards',()=>{
 const round=routes.filter(r=>r.externalSource.returnTrackMirrored);
 assert.equal(round.length,2);
 for(const r of round){
  assert(r.dayPlan.description.includes('ters yönde'));
  const pts=r.dayPlan.geometry;
  for(let i=0;i<pts.length;i++) assert.deepEqual(pts[i],pts[pts.length-1-i]);
  assert.equal(r.stopSnapshots.length,3);
 }
});
