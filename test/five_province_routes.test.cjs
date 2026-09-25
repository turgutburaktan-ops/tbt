const test=require('node:test'),assert=require('node:assert/strict');
const {validate}=require('../functions/scripts/publish_elazig_external_routes.cjs');
const {validatePhoto}=require('../functions/scripts/ready_route_sources.cjs');
const routes=require('../functions/scripts/five_province_routes.json'),photos=require('../functions/scripts/five_province_photos.json');
const old=['elazig_external_routes','elazig_expansion_routes','nearby_ready_routes','nearby_expansion_routes'].flatMap(f=>require('../functions/scripts/'+f+'.json'));
const rad=x=>x*Math.PI/180;
function meters(a,b){return 6371000*2*Math.asin(Math.min(1,Math.sqrt(Math.sin(rad(b.lat-a.lat)/2)**2+Math.cos(rad(a.lat))*Math.cos(rad(b.lat))*Math.sin(rad(b.lng-a.lng)/2)**2)));}
test('twelve additions cover all five provinces with no duplicate source tracks',()=>{
 validate(routes);assert.equal(routes.length,12);
 assert.deepEqual(routes.reduce((a,r)=>(a[r.city]=(a[r.city]||0)+1,a),{}),{'Elazığ':4,'Malatya':2,'Tunceli':2,'Bingöl':2,'Diyarbakır':2});
 assert.deepEqual(photos.map(p=>p.id),routes.map(r=>r.id));
 assert.equal(new Set([...routes,...old].map(r=>r.id)).size,37);
 assert.equal(new Set([...routes,...old].map(r=>r.externalSource.sha256)).size,37);
 routes.forEach((r,i)=>{
  validatePhoto(photos[i],r);assert(Math.abs(r.distanceKm/r.externalSource.publishedDistanceKm-1)<.25);
  const pts=r.dayPlan.geometry;const ds=pts.slice(1).map((p,j)=>meters(pts[j],p));
  assert(Math.max(...ds)<700);assert(Math.abs(ds.reduce((a,b)=>a+b,0)/1000-r.distanceKm)<.001);
 });
});
test('Kockale and Icme return legs exactly mirror their source outbound geometry and disclose this',()=>{
 const mirrored=routes.filter(r=>r.externalSource.returnTrackMirrored);assert.equal(mirrored.length,2);
 for(const r of mirrored){
  const pts=r.dayPlan.geometry;assert.equal(r.stopSnapshots.length,3);assert.equal(r.dayPlan.legs.length,2);
  assert(r.dayPlan.description.includes('ters yönde'));
  pts.forEach((p,i)=>assert.deepEqual(p,pts[pts.length-1-i]));
  assert(Math.abs(r.distanceKm*1000-r.externalSource.originalSelectedTrackMeters*2)<.001);
 }
});
test('long Ovacik track retains endpoints and less than one percent length change',()=>{
 const r=routes.find(r=>r.id.endsWith('merkez_ovacik_bisiklet_rotasi'));
 assert.equal(r.externalSource.simplificationToleranceMeters,2);assert.equal(r.externalSource.trackPointCount,2340);
 assert(r.dayPlan.geometry.length<2000);
 assert.deepEqual(r.dayPlan.geometry[0],{lat:39.1047181975688,lng:39.54734934999196});
 assert.deepEqual(r.dayPlan.geometry.at(-1),{lat:39.35730179882074,lng:39.21447859972626});
 assert(Math.abs(r.distanceKm*1000/r.externalSource.originalSelectedTrackMeters-1)<.01);
 assert(r.dayPlan.description.includes('2 metre toleransla'));
});
test('Diyarbakir imports only named walking lines and no car access',()=>{
 const selected=routes.filter(r=>r.city==='Diyarbakır');
 assert.deepEqual(selected.map(r=>r.dayPlan.geometry.length),[1019,1853]);
 assert(Math.abs(selected[0].distanceKm-15.594)<.01);assert(Math.abs(selected[1].distanceKm-44.632)<.01);
 selected.forEach(r=>assert(r.dayPlan.description.includes('araçla ulaşım yolları dahil değildir')));
});
