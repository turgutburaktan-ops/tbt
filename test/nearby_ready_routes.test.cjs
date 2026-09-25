const test=require('node:test');
const assert=require('node:assert/strict');
const {validate}=require('../functions/scripts/publish_elazig_external_routes.cjs');
const {validatePhoto,creditLine}=require('../functions/scripts/ready_route_sources.cjs');
const routes=require('../functions/scripts/nearby_ready_routes.json');
const photos=require('../functions/scripts/nearby_route_photos.json');
const previous=[...require('../functions/scripts/elazig_external_routes.json'),...require('../functions/scripts/elazig_expansion_routes.json')];
test('five photographed routes cover four neighboring provinces without duplicating imports',()=>{
 validate(routes);
 assert.deepEqual(routes.map(r=>r.city),['Malatya','Malatya','Tunceli','Bingöl','Diyarbakır']);
 assert.deepEqual(photos.map(p=>p.id),routes.map(r=>r.id));
 assert.equal(new Set([...routes,...previous].map(r=>r.id)).size,15);
 assert.equal(new Set([...routes,...previous].map(r=>r.externalSource.sha256)).size,15);
 routes.forEach((r,i)=>{
  validatePhoto(photos[i],r);
  assert(Math.abs(r.distanceKm/r.externalSource.publishedDistanceKm-1)<.25);
  assert.equal(r.externalSource.fieldVerified,false);
 });
});
test('Tunceli uses only the selected walking segment, excluding the car approach',()=>{
 const r=routes.find(r=>r.city==='Tunceli');
 assert.equal(r.externalSource.selectedTrackName,'Kırk Merdiven Şelalesi Rotası');
 assert.equal(r.dayPlan.geometry.length,1247);
 assert(Math.abs(r.distanceKm-12.2072226)<.001);
 assert.deepEqual(r.dayPlan.geometry[0],{lat:39.41665998660028,lng:39.2243757750839});
 assert(r.dayPlan.description.includes('araçla ulaşım yolu dahil değildir'));
});
test('province/source mismatches, off-region geometry and foreign photo URLs are rejected',()=>{
 for(const edit of [r=>r.city='Elazığ',r=>r.externalSource.url=r.externalSource.url.replace('/malatya/','/bingol/'),r=>r.dayPlan.geometry[10].lat=41]){
  const copy=structuredClone(routes);edit(copy[0]);assert.throws(()=>validate(copy));
 }
 const bad={...photos[0],sourceUrl:'https://example.com/photo.jpg'};
 assert.throws(()=>validatePhoto(bad,routes[0]));
 assert.throws(()=>validatePhoto({...photos[0],sourcePage:photos[1].sourcePage},routes[0]));
});
test('existing cover credits remain byte-compatible and all previous photos still validate',()=>{
 const old=[...require('../functions/scripts/elazig_route_photos.json'),...require('../functions/scripts/elazig_expansion_photos.json')];
 old.forEach((p,i)=>{
  validatePhoto(p,previous[i]);
  assert.equal(creditLine(p),'\nKapak fotoğrafı: Fırat’ı Keşfet (rota kaynak sayfası).');
 });
});
