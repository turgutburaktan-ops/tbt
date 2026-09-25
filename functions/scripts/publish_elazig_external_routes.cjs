'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const definitions = require(process.env.ROUTE_MANIFEST || './elazig_external_routes.json');
const digest = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');

function validate(routes) {
  assert(routes.length > 0 && routes.length <= 30);
  assert.equal(new Set(routes.map(r => r.id)).size, routes.length);
  for (const r of routes) {
    assert.match(r.id, /^tbt_ready_firat_elazig_[a-z_]+$/);
    assert.equal(r.city, 'Elazığ');
    assert(['Yürüyüş','Bisiklet'].includes(r.transport));
    assert(r.distanceKm > 0 && r.distanceKm < 100);
    assert(Number.isInteger(r.travelMinutes) && r.travelMinutes > 0);
    assert(r.stopSnapshots.length >= 2 && r.stopSnapshots.length <= 12);
    assert.deepEqual(r.spotIds, r.stopSnapshots.map(s => s.id));
    assert.deepEqual(r.spotNames, r.stopSnapshots.map(s => s.name));
    assert.equal(new Set(r.spotIds).size, r.spotIds.length);
    for (const s of r.stopSnapshots) {
      assert(s.id.startsWith('external_firat_'));
      assert(s.name && s.city === r.city);
      assert(Number.isFinite(s.latitude) && s.latitude > 38 && s.latitude < 40);
      assert(Number.isFinite(s.longitude) && s.longitude > 38 && s.longitude < 41);
    }
    const day = r.dayPlan;
    assert.equal(day.signature, `${r.transport}|null,null|false|${r.stopSnapshots.map(s=>`${s.latitude},${s.longitude}`).join(';')}`);
    assert.equal(day.routeVersion, 2);
    assert.equal(day.manual, false);
    assert.equal(day.roundTrip, false);
    assert(day.geometry.length > 10 && day.geometry.length <= 2000);
    for (const p of day.geometry) {
      assert(Number.isFinite(p.lat) && p.lat > 38 && p.lat < 40);
      assert(Number.isFinite(p.lng) && p.lng > 38 && p.lng < 41);
    }
    for (const s of r.stopSnapshots) assert(day.geometry.some(p=>p.lat===s.latitude && p.lng===s.longitude));
    assert.equal(day.geometry[0].lat, r.stopSnapshots[0].latitude);
    assert.equal(day.geometry.at(-1).lng, r.stopSnapshots.at(-1).longitude);
    assert.equal(day.legs.length, r.spotIds.length-1);
    assert(day.legs.every(l=>Number.isFinite(l.meters)&&l.meters>0&&Number.isFinite(l.seconds)&&l.seconds>0));
    assert(Math.abs(day.legs.reduce((s,l)=>s+l.meters,0)/1000-r.distanceKm)<0.001);
    assert(Math.abs(day.legs.reduce((s,l)=>s+l.seconds,0)/60-r.travelMinutes)<0.001);
    assert.equal(new URL(r.externalSource.url).hostname, 'firatikesfet.com');
    assert.match(r.externalSource.sha256, /^[a-f0-9]{64}$/);
    assert(day.description.includes(r.externalSource.url));
    assert(['Kolay','Orta','Zor'].includes(day.difficulty));
    assert(Buffer.byteLength(JSON.stringify(r)) < 200000);
  }
  return routes;
}

async function publish() {
  validate(definitions);
  if (process.env.PUBLISH_EXTERNAL_ROUTES !== 'true') {
    console.log('VERIFIED_EXTERNAL_ROUTES '+definitions.length); return;
  }
  const admin = require('firebase-admin');
  const credential = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  assert.equal(credential.project_id,'en-iyi-cekim-noktasi');
  admin.initializeApp({credential:admin.credential.cert(credential)});
  const db=admin.firestore();
  const owner=await admin.auth().getUserByEmail('turgutburaktan@gmail.com');
  const refs=definitions.map(r=>db.collection('travel_plans').doc(r.id));
  await db.runTransaction(async tx=>{
    const existing=await tx.getAll(...refs);
    for(let i=0;i<definitions.length;i++) {
      const r=definitions[i], hash=digest(r), old=existing[i];
      if(old.exists) {
        assert.equal(old.data().ownerId,owner.uid,'Reserved ID owner conflict');
        assert.equal(old.data().externalImportHash,hash,'Existing route differs; refusing overwrite');
        continue;
      }
      const {id,...content}=r;
      const now=admin.firestore.Timestamp.now();
      tx.create(refs[i],{...content,ownerId:owner.uid,ownerName:'TBT',area:'',mealPreferences:[],
        budget:'Orta',interests:['Gezi'],memberIds:[],estimatedBudget:0,weatherSummary:'',
        visibility:'public',status:'planned',hasSchedule:false,allowMemberEdits:false,
        isPublic:true,discoverPublished:true,accessVersion:2,joinEnabled:false,
        joinAudience:'private',joinRequiresApproval:true,invitedIds:[],routeOrigin:{},
        startAt:now,createdAt:now,updatedAt:now,externalImportVersion:1,externalImportHash:hash});
    }
  });
  const readback=await db.getAll(...refs);
  for(let i=0;i<readback.length;i++) {
    const data=readback[i].data(), expected=definitions[i];
    assert.equal(data.externalImportHash,digest(expected));
    // A separately verified cover-photo migration may enrich these two fields.
    const comparable={...data};
    if(data.externalRoutePhoto?.version===1) {
      const photo=data.externalRoutePhoto;
      assert.equal(photo.id,readback[i].id);
      assert.equal(new URL(photo.sourceUrl).origin,'https://firatikesfet.com');
      assert.equal(new URL(photo.imageUrl).hostname,'firebasestorage.googleapis.com');
      assert.equal(data.stopSnapshots[0].imageUrl,photo.imageUrl);
      comparable.stopSnapshots=data.stopSnapshots.map((s,n)=>n===0?{...s,imageUrl:expected.stopSnapshots[0].imageUrl}:s);
      assert.equal(data.dayPlan.description,expected.dayPlan.description+'\nKapak fotoğrafı: Fırat’ı Keşfet (rota kaynak sayfası).');
      comparable.dayPlan={...data.dayPlan,description:expected.dayPlan.description};
    }
    for(const [key,value] of Object.entries(expected)) if(key!=='id') assert.deepEqual(comparable[key],value);
    assert.deepEqual(data.memberIds,[]);
    assert.deepEqual(data.invitedIds,[]);
    assert.equal(data.isPublic,true);
    assert.equal(data.discoverPublished,true);
    assert.equal(data.hasSchedule,false);
    console.log('EXTERNAL_ROUTE_LIVE '+JSON.stringify({id:readback[i].id,title:data.title,city:data.city,
      points:data.dayPlan.geometry.length,stops:data.spotIds.length,distanceKm:data.distanceKm}));
  }
  console.log('PUBLISHED_AND_VERIFIED_EXTERNAL_ROUTES '+readback.length);
}
module.exports={validate};
if(require.main===module) publish().catch(e=>{console.error(e.message);process.exitCode=1;});
