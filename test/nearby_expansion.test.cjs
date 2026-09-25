const test=require('node:test');
const assert=require('node:assert/strict');
const {validate}=require('../functions/scripts/publish_elazig_external_routes.cjs');
const {validatePhoto}=require('../functions/scripts/ready_route_sources.cjs');
const routes=require('../functions/scripts/nearby_expansion_routes.json');
const photos=require('../functions/scripts/nearby_expansion_photos.json');
const previous=[...require('../functions/scripts/elazig_external_routes.json'),...require('../functions/scripts/elazig_expansion_routes.json'),...require('../functions/scripts/nearby_ready_routes.json')];
test('ten additions retain city filtering, valid geometry and one reviewed cover each',()=>{
 validate(routes);assert.equal(routes.length,10);
 assert.deepEqual(routes.reduce((a,r)=>(a[r.city]=(a[r.city]||0)+1,a),{}),{'Malatya':3,'Tunceli':2,'Bingöl':3,'Diyarbakır':2});
 assert.deepEqual(photos.map(p=>p.id),routes.map(r=>r.id));
 const all=[...routes,...previous];
 assert.equal(new Set(all.map(r=>r.id)).size,25);
 assert.equal(new Set(all.map(r=>r.externalSource.sha256)).size,25);
 routes.forEach((r,i)=>{validatePhoto(photos[i],r);assert(Math.abs(r.distanceKm/r.externalSource.publishedDistanceKm-1)<.25);assert.equal(r.externalSource.fieldVerified,false);});
});
test('Diyarbakir walking distances exclude both inbound and outbound car tracks',()=>{
 const selected=routes.filter(r=>r.city==='Diyarbakır');
 assert.deepEqual(selected.map(r=>r.externalSource.selectedTrackName),['KARACADAG LAV YOLU ROTASI IZ-F','ÇEMERES ZERZEVAN ROTASI IZ-F']);
 assert.deepEqual(selected.map(r=>r.dayPlan.geometry.length),[611,1367]);
 assert(Math.abs(selected[0].distanceKm-11.243)<.01);
 assert(Math.abs(selected[1].distanceKm-14.498)<.01);
 selected.forEach(r=>assert(r.dayPlan.description.includes('araçla ulaşım yolları dahil değildir')));
 assert(selected[1].dayPlan.description.includes('Mardin–Mazıdağı'));
});
test('Tunceli source roundtrip label conflicts are disclosed and no return path is invented',()=>{
 const selected=routes.filter(r=>r.city==='Tunceli');
 assert.deepEqual(selected.map(r=>r.dayPlan.geometry.length),[555,698]);
 selected.forEach(r=>{
  assert.equal(r.externalSource.returnTrackMirrored,false);
  assert(r.dayPlan.description.includes('tek yönlü iz'));
  assert.notDeepEqual(r.dayPlan.geometry[0],r.dayPlan.geometry.at(-1));
 });
});
