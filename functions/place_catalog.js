const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp, FieldPath} = require('firebase-admin/firestore');
const {project} = require('./catalog/store');
const {provinces, kinds, meters} = require('./catalog/schema');
const {refreshPartition} = require('./catalog/importer');
const opts = {region:'europe-west1', retry:true};
exports.catalogSpotWritten = onDocumentWritten({...opts,document:'photo_spots/{id}'}, e=>project(getFirestore(),'spot',e.params.id));
exports.catalogBusinessWritten = onDocumentWritten({...opts,document:'business_venues/{id}'}, e=>project(getFirestore(),'venue',e.params.id,
  {removedApprovedBusiness: e.data?.before?.data()?.verified === true}));
exports.catalogExternalWritten = onDocumentWritten({...opts,document:'catalog_external_venues/{id}'}, e=>project(getFirestore(),'venue',e.params.id));

exports.refreshPlaceCatalog = onSchedule({region:'europe-west1',schedule:'every 15 minutes',timeoutSeconds:540,memory:'512MiB',maxInstances:1}, async ()=>{
  const db=getFirestore(), state=db.doc('catalog_jobs/refresh');
  const slot=await db.runTransaction(async tx=>{
    const d=(await tx.get(state)).data()||{};
    if(d.leaseUntil?.toMillis()>Date.now())return null;
    const index=Number(d.next||0)%(81*3);
    tx.set(state,{next:(index+1)%(81*3),leaseUntil:Timestamp.fromMillis(Date.now()+10*60000)},{merge:true});
    return index;
  });
  if(slot===null)return;
  try { await refreshPartition(db,provinces[Math.floor(slot/3)],kinds[1+slot%3]); }
  finally { await state.set({leaseUntil:FieldValue.delete(),lastFinishedAt:FieldValue.serverTimestamp()},{merge:true}); }
});

// Compatibility for older map/day-plan callers that have coordinates instead
// of a selected province. It also reads only our persisted public catalog.
exports.catalogNearby = onCall({region:'europe-west1',timeoutSeconds:60,maxInstances:5}, async request=>{
  const d=request.data||{}, latitude=Number(d.latitude),longitude=Number(d.longitude);
  const radius=Math.min(80000,Math.max(1000,Number(d.radiusMeters)||25000));
  if(!kinds.slice(1).includes(d.kind)||!Number.isFinite(latitude)||!Number.isFinite(longitude)||latitude<35.4||latitude>42.3||longitude<25.4||longitude>45.1)throw new HttpsError('invalid-argument','Geçerli konum ve kategori gerekli.');
  const db=getFirestore(), result=[];
  const partitions=await db.collection('place_catalog').where('kind','==',d.kind).get();
  const latDelta=radius/110000,lonDelta=radius/(110000*Math.cos(latitude*Math.PI/180));
  for(const doc of partitions.docs){
    const m=doc.data();
    if(!m.count || m.maxLatitude<latitude-latDelta||m.minLatitude>latitude+latDelta||m.maxLongitude<longitude-lonDelta||m.minLongitude>longitude+lonDelta)continue;
    let after=null;
    while(true){
      let q=doc.ref.collection('items').orderBy(FieldPath.documentId()).limit(200);if(after)q=q.startAfter(after);
      const page=await q.get();
      for(const p of page.docs)if(meters({latitude,longitude},p.data())<=radius)result.push(p.data());
      if(page.size<200)break;after=page.docs.at(-1).id;
    }
  }
  result.sort((a,b)=>meters({latitude,longitude},a)-meters({latitude,longitude},b));
  return {items:result.slice(0,1000),hasMore:result.length>1000};
});
