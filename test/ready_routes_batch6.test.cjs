const test=require('node:test'),assert=require('node:assert/strict');
const {validate}=require('../functions/scripts/publish_elazig_external_routes.cjs');
const {validatePhoto}=require('../functions/scripts/ready_route_sources.cjs');
const routes=require('../functions/scripts/ready_routes_batch6.json'),photos=require('../functions/scripts/ready_route_photos_batch6.json');
const previous=['elazig_external_routes','elazig_expansion_routes','nearby_ready_routes','nearby_expansion_routes','five_province_routes'].flatMap(f=>require('../functions/scripts/'+f+'.json'));
const radians=x=>x*Math.PI/180;
function meters(a,b){return 6371000*2*Math.asin(Math.min(1,Math.sqrt(Math.sin(radians(b.lat-a.lat)/2)**2+Math.cos(radians(a.lat))*Math.cos(radians(b.lat))*Math.sin(radians(b.lng-a.lng)/2)**2)));}
test('thirteen photographed additions bring the reviewed source catalog to fifty unique tracks',()=>{
 validate(routes);assert.equal(routes.length,13);
 assert.deepEqual(routes.reduce((a,r)=>(a[r.city]=(a[r.city]||0)+1,a),{}),{'Elazığ':4,'Malatya':3,'Bingöl':2,'Tunceli':2,'Diyarbakır':2});
 assert.deepEqual(photos.map(p=>p.id),routes.map(r=>r.id));
 const all=[...previous,...routes];assert.equal(all.length,50);
 assert.equal(new Set(all.map(r=>r.id)).size,50);assert.equal(new Set(all.map(r=>r.externalSource.sha256)).size,50);
 routes.forEach((r,i)=>{
  validatePhoto(photos[i],r);assert.equal(r.externalSource.fieldVerified,false);
  assert(Math.abs(r.distanceKm/r.externalSource.publishedDistanceKm-1)<.25);
  const pts=r.dayPlan.geometry,ds=pts.slice(1).map((p,n)=>meters(pts[n],p));
  assert(Math.max(...ds)<700);assert(Math.abs(ds.reduce((a,b)=>a+b,0)/1000-r.distanceKm)<.001);
 });
});
test('Egil contains the short walking segment rather than the car approach',()=>{
 const r=routes.find(r=>r.city==='Diyarbakır'&&r.title.startsWith('Eğil'));
 assert.equal(r.externalSource.selectedTrackName,'PEYGAMBERLER MAKAMI-EĞİL KALESİ ROTASI- 002');
 assert.equal(r.dayPlan.geometry.length,422);assert(Math.abs(r.distanceKm-3.383)<.01);
 assert.deepEqual(r.dayPlan.geometry[0],{lat:38.252838011831045,lng:40.09755743667483});
 assert(r.dayPlan.description.includes('araçla ulaşım yolu dahil değildir'));
});
test('Hozat track is attached only to the matching source page and preserves the very hard source label',()=>{
 const r=routes.find(r=>r.id.endsWith('hozat_gozeler_rotasi'));
 assert(r.externalSource.url.endsWith('/hozat-gozeler-rotasi'));
 assert.equal(r.externalSource.selectedTrackName,'Hozat - Ovacık Gözeler Bisiklet Rotası');
 assert.deepEqual(r.dayPlan.geometry[0],{lat:39.10787281418729,lng:39.2189301889695});
 assert.equal(r.externalSource.publishedDifficulty,'Çok zor');assert.equal(r.dayPlan.difficulty,'Zor');
 assert(r.dayPlan.description.includes('Kaynak zorluğu: Çok zor.'));assert(r.dayPlan.description.includes('tek yönlü iz'));
 for(const slug of ['pertek_cataksu_rotasi','ovacik_gozeler_rotasi','genc_tarihi_koprusu_caytepe_koyu_bisiklet_parkuru']) assert(!routes.some(x=>x.id.endsWith(slug)));
});
