const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp, FieldPath} = require('firebase-admin/firestore');

function auth(request) { if (!request.auth?.uid) throw new HttpsError('unauthenticated','Giriş gerekli.'); return request.auth.uid; }
function clean(v,n=200){return String(v||'').trim().slice(0,n)}
function isPremium(d){return d.status==='verified'||d.proEntitled===true||d.plan==='business_pro_free'||d.premiumEntitled===true}
async function claimFor(db,venueKey){const s=await db.collection('business_claims').doc(venueKey).get();return{s,data:s.data()||{}}}
async function owner(request,venueKey,{premium=false}={}){const uid=auth(request),db=getFirestore(),[c,v]=await Promise.all([claimFor(db,venueKey),db.collection('business_venues').doc(venueKey).get()]),d=c.data,venue=v.data()||{},ownsClaim=d.status==='verified'&&d.applicantUid===uid,ownsVenue=venue.verified===true&&venue.ownerUid===uid;if(!ownsClaim&&!ownsVenue)throw new HttpsError('permission-denied','Doğrulanmış işletme sahibi gerekli.');if(premium&&!isPremium(d)&&venue.verified!==true)throw new HttpsError('failed-precondition','Bu özellik TBT Business gerektiriyor.');return{uid,db,claim:d,venue}}

exports.followBusiness = onCall({region:'europe-west1'}, async request=>{const uid=auth(request),venueKey=clean(request.data?.venueKey,240),follow=request.data?.follow!==false;if(!venueKey)throw new HttpsError('invalid-argument','İşletme gerekli.');const db=getFirestore(),ref=db.collection('business_venues').doc(venueKey).collection('followers').doc(uid);if(follow)await ref.set({uid,createdAt:FieldValue.serverTimestamp()});else await ref.delete();return{following:follow};});
exports.getBusinessFollowStatus = onCall({region:'europe-west1'}, async request=>{const uid=auth(request),venueKey=clean(request.data?.venueKey,240);if(!venueKey)throw new HttpsError('invalid-argument','İşletme gerekli.');const snap=await getFirestore().collection('business_venues').doc(venueKey).collection('followers').doc(uid).get();return{following:snap.exists};});
exports.getBusinessPublicFeatures = onCall({region:'europe-west1'}, async request=>{auth(request);const venueKey=clean(request.data?.venueKey,240);if(!venueKey)throw new HttpsError('invalid-argument','İşletme gerekli.');const db=getFirestore(),c=await claimFor(db,venueKey);return{verified:c.data.status==='verified',reservationsEnabled:c.data.status==='verified',premiumActive:isPremium(c.data)};});

exports.recordBusinessMetric = onCall({region:'europe-west1'}, async request=>{
  const uid=auth(request),venueKey=clean(request.data?.venueKey,240),metric=clean(request.data?.metric,40);
  const allowed=new Set(['profile_view','directions','phone','menu_view','campaign_view','campaign_save','event_view','reservation_open']);
  if(!venueKey||!allowed.has(metric))throw new HttpsError('invalid-argument','Geçersiz istatistik.');
  const db=getFirestore(),base=db.collection('business_venues').doc(venueKey),venue=await base.get(),data=venue.data()||{},day=new Date().toISOString().slice(0,10),batch=db.batch();
  batch.set(base.collection('metrics').doc(metric),{count:FieldValue.increment(1),updatedAt:FieldValue.serverTimestamp()},{merge:true});
  batch.set(base.collection('metric_days').doc(day),{[metric]:FieldValue.increment(1),total:FieldValue.increment(1),updatedAt:FieldValue.serverTimestamp()},{merge:true});
  const boostId=clean(data.activeBoostId,180),boostUntil=data.boostActiveUntil?.toMillis?.()||0;
  if(boostId&&boostUntil>Date.now()){
    const impression=metric.endsWith('_view'),click=['directions','phone','campaign_save','reservation_open'].includes(metric);
    batch.set(base.collection('boosts').doc(boostId),{impressions:FieldValue.increment(impression?1:0),clicks:FieldValue.increment(click?1:0),lastMetricAt:FieldValue.serverTimestamp(),lastMetricBy:uid},{merge:true});
  }
  await batch.commit();return{ok:true};
});

exports.getBusinessDashboard = onCall({region:'europe-west1'}, async request=>{
  const venueKey=clean(request.data?.venueKey,240),{db}=await owner(request,venueKey),base=db.collection('business_venues').doc(venueKey),venue=await base.get(),venueData=venue.data()||{};
  const boostId=clean(venueData.activeBoostId,180);
  const [metrics,days,followers,reservations,boost]=await Promise.all([
    base.collection('metrics').get().catch(error=>{console.error('dashboard metrics',error);return{docs:[]};}),
    base.collection('metric_days').orderBy(FieldPath.documentId(),'desc').limit(7).get().catch(error=>{console.error('dashboard days',error);return{docs:[]};}),
    base.collection('followers').count().get().catch(error=>{console.error('dashboard followers',error);return{data:()=>({count:0})};}),
    base.collection('reservations').orderBy('createdAt','desc').limit(30).get().catch(error=>{console.error('dashboard reservations',error);return{docs:[]};}),
    boostId?base.collection('boosts').doc(boostId).get().catch(error=>{console.error('dashboard boost',error);return null;}):Promise.resolve(null)
  ]);
  const out={};metrics.docs.forEach(d=>out[d.id]=Number(d.data().count||0));
  const daily=days.docs.map(doc=>({date:doc.id,...doc.data()}));
  const reservationItems=reservations.docs.map(doc=>{const d=doc.data()||{};return{id:doc.id,userUid:clean(d.userUid,180),partySize:Number(d.partySize||0),atMs:d.at?.toMillis?.()||0,note:clean(d.note,500),status:clean(d.status,20),createdAtMs:d.createdAt?.toMillis?.()||0};});
  const boostData=boost?.exists?boost.data()||{}:null;
  return{metrics:out,daily,followers:followers.data().count,reservations:reservationItems,boost:boostData?{id:boost.id,targetType:clean(boostData.targetType,30),targetId:clean(boostData.targetId,180),status:clean(boostData.status,20),startsAtMs:boostData.startsAt?.toMillis?.()||0,endsAtMs:boostData.endsAt?.toMillis?.()||0,impressions:Number(boostData.impressions||0),clicks:Number(boostData.clicks||0)}:null};
});

exports.requestBusinessReservation = onCall({region:'europe-west1'}, async request=>{const uid=auth(request),venueKey=clean(request.data?.venueKey,240),partySize=Number(request.data?.partySize||0),atMs=Number(request.data?.atMs||0),note=clean(request.data?.note,500);if(!venueKey||!Number.isInteger(partySize)||partySize<1||partySize>50||atMs<Date.now())throw new HttpsError('invalid-argument','Rezervasyon bilgileri geçersiz.');const db=getFirestore(),c=await claimFor(db,venueKey);if(c.data.status!=='verified')throw new HttpsError('failed-precondition','Bu işletmede rezervasyon özelliği aktif değil.');const venue=await db.collection('business_venues').doc(venueKey).get();if(!venue.exists||venue.data()?.verified!==true)throw new HttpsError('failed-precondition','İşletme doğrulanmamış.');const recent=await venue.ref.collection('reservations').where('userUid','==',uid).limit(20).get();const pendingCount=recent.docs.filter(doc=>(doc.data()?.status||'')==='pending').length;if(pendingCount>=3)throw new HttpsError('resource-exhausted','Bu işletmede çok fazla bekleyen rezervasyon talebin var.');const ref=await venue.ref.collection('reservations').add({userUid:uid,partySize,at:Timestamp.fromMillis(atMs),note,status:'pending',createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});return{id:ref.id,status:'pending'};});

exports.respondBusinessReservation = onCall({region:'europe-west1'}, async request=>{const venueKey=clean(request.data?.venueKey,240),reservationId=clean(request.data?.reservationId,180),decision=clean(request.data?.decision,20),{db}=await owner(request,venueKey);if(!['accepted','rejected'].includes(decision))throw new HttpsError('invalid-argument','Geçersiz karar.');const ref=db.collection('business_venues').doc(venueKey).collection('reservations').doc(reservationId);const snap=await ref.get();if(!snap.exists)throw new HttpsError('not-found','Rezervasyon bulunamadı.');if((snap.data()?.status||'')!=='pending')throw new HttpsError('failed-precondition','Bu rezervasyon zaten sonuçlandırılmış.');await ref.update({status:decision,updatedAt:FieldValue.serverTimestamp()});return{status:decision};});

exports.createBusinessBoost = onCall({region:'europe-west1'}, async request=>{
  const venueKey=clean(request.data?.venueKey,240),targetType=clean(request.data?.targetType,30),targetId=clean(request.data?.targetId,180),days=Math.min(30,Math.max(1,Number(request.data?.days||3))),{uid,db}=await owner(request,venueKey,{premium:true});
  if(!['profile','campaign','event'].includes(targetType))throw new HttpsError('invalid-argument','Geçersiz Boost hedefi.');
  const base=db.collection('business_venues').doc(venueKey);
  if(targetType!=='profile'){
    if(!targetId)throw new HttpsError('invalid-argument','Öne çıkarılacak içerik seçilmedi.');
    const collectionName=targetType==='campaign'?'campaigns':'program';
    const target=await base.collection(collectionName).doc(targetId).get();
    const data=target.data()||{};
    if(!target.exists||data.active===false)throw new HttpsError('failed-precondition','Seçilen içerik yayında değil veya bulunamadı.');
    const targetDate=targetType==='campaign'?data.validUntil:data.startsAt;
    if(targetDate?.toMillis?.()<=Date.now())throw new HttpsError('failed-precondition','Süresi geçmiş içerik öne çıkarılamaz.');
  }
  const active=await base.collection('boosts').where('endsAt','>',Timestamp.now()).limit(1).get();
  if(!active.empty)throw new HttpsError('already-exists','Bu işletmede aktif bir Boost zaten var.');
  const until=Timestamp.fromMillis(Date.now()+days*86400000);
  const boostRef=base.collection('boosts').doc();
  await boostRef.set({targetType,targetId,days,status:'active',billingStatus:'free_launch',startsAt:FieldValue.serverTimestamp(),endsAt:until,createdBy:uid,impressions:0,clicks:0});
  await base.set({boostActive:true,activeBoostId:boostRef.id,boostActiveUntil:until,boostTargetType:targetType,boostTargetId:targetId,updatedAt:FieldValue.serverTimestamp()},{merge:true});
  return{status:'active',endsAtMs:until.toMillis()};
});
