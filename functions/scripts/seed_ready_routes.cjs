'use strict';
const admin = require('firebase-admin');
const fs = require('node:fs');
const {spotRow} = require('../catalog/schema');
const definitions = require('./ready_routes.json');
async function main() {
  const credential = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  if (credential.project_id !== 'en-iyi-cekim-noktasi') throw Error('Unexpected project');
  admin.initializeApp({credential: admin.credential.cert(credential)});
  const db = admin.firestore();
  const owner = await admin.auth().getUserByEmail('turgutburaktan@gmail.com');
  const plans = [], report = [];
  for (const definition of definitions) {
    try {
      if (!definition.stops || definition.stops.length < 2) throw Error('Additional verified stops required');
      const stops = [];
      for (const id of definition.stops) {
        const doc = await db.collection('photo_spots').doc(id).get();
        const row = spotRow(id, doc.data() || {});
        if (!row || row.city !== definition.city) throw Error('Stop no longer verified: ' + id);
        stops.push({id, name:row.name, city:row.city, latitude:row.latitude, longitude:row.longitude, imageUrl:row.imageUrl, category:'Gezi', description:'', bestTime:''});
      }
      const graph = {'Araç':'car','Yürüyüş':'foot','Bisiklet':'bike'}[definition.transport];
      if (!graph) throw Error('Invalid mode');
      await new Promise(resolve => setTimeout(resolve, 1200));
      const coords = stops.map(s => `${s.longitude},${s.latitude}`).join(';');
      const url = `https://routing.openstreetmap.de/routed-${graph}/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=false&radiuses=${stops.map(()=>250).join(';')}`;
      const response = await fetch(url,{signal:AbortSignal.timeout(20000),headers:{'User-Agent':'TBT/1.0 route-planner'}});
      if (!response.ok) throw Error('Routing HTTP ' + response.status);
      const body = await response.json(), route = body.routes?.[0];
      if (body.code !== 'Ok' || !route || route.legs.length !== stops.length - 1 || !(route.distance > 0) || !Number.isFinite(route.duration)) throw Error('No verified route');
      if (body.waypoints?.some(p => p.distance > 250)) throw Error('Stop too far from route');
      const points = route.geometry.coordinates;
      const step = Math.max(1,Math.ceil(points.length/1700));
      const geometry = points.filter((_,i)=>i%step===0 || i===points.length-1).map(([lng,lat])=>({lat,lng}));
      const distanceKm=route.distance/1000, travelMinutes=Math.ceil(route.duration/60);
      const dayPlan={routeVersion:2,signature:`${definition.transport}|null,null|false|${stops.map(s=>`${s.latitude},${s.longitude}`).join(';')}`,manual:false,roundTrip:false,geometry,legs:route.legs.map(l=>({meters:l.distance,seconds:l.duration})),description:definition.description};
      if (graph !== 'car') {
        dayPlan.difficulty = distanceKm >= (graph==='foot'?15:50) ? 'Zor' : distanceKm >= (graph==='foot'?6:20) ? 'Orta' : 'Kolay';
        dayPlan.difficultyEstimated = true;
        dayPlan.description += ' Zorluk yalnızca mesafeye göre tahmin edilmiştir; eğim ve zemin henüz değerlendirilmedi.';
      }
      const now=admin.firestore.Timestamp.now();
      plans.push({id:definition.id,data:{ownerId:owner.uid,ownerName:'TBT',title:definition.title,city:definition.city,area:'',mealPreferences:[],durationHours:Math.max(1,Math.ceil((travelMinutes+45*stops.length)/60)),budget:'Orta',transport:definition.transport,interests:['Gezi'],spotIds:stops.map(s=>s.id),spotNames:stops.map(s=>s.name),stopSnapshots:stops,memberIds:[],distanceKm,travelMinutes,estimatedBudget:0,weatherSummary:'',dayPlan,visibility:'public',status:'planned',hasSchedule:false,allowMemberEdits:false,isPublic:true,discoverPublished:true,accessVersion:2,joinEnabled:false,joinAudience:'private',joinRequiresApproval:true,invitedIds:[],routeOrigin:{},startAt:now,createdAt:now,updatedAt:now,readySeedVersion:1}});
      report.push({id:definition.id,title:definition.title,status:'verified',distanceKm,travelMinutes});
    } catch(e) {report.push({id:definition.id,title:definition.title,status:'pending',reason:e.message});}
  }
  fs.writeFileSync('ready-route-report.json',JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
  if (process.env.PUBLISH_READY_ROUTES !== 'true') return;
  // One transaction: create missing editorial documents, never overwrite a route.
  await db.runTransaction(async tx=>{
    const refs=plans.map(p=>db.collection('travel_plans').doc(p.id));
    const existing=refs.length ? await tx.getAll(...refs) : [];
    for(let i=0;i<plans.length;i++) {
      if(existing[i].exists) {
        if(existing[i].data().readySeedVersion!==1 || existing[i].data().ownerId!==owner.uid) throw Error('Reserved ID conflict');
      } else tx.create(refs[i],plans[i].data);
    }
  });
  console.log('AVAILABLE_READY_ROUTES '+plans.length);
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
