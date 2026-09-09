const {syncReminder}=require('./reservation_reminders');
const {customerHistory}=require('./reservation_history');
const {orderSelection,pricedOrder,reservationView}=require('./reservation_details');
const {createHash}=require('crypto');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp, FieldPath} = require('firebase-admin/firestore');

function auth(request) { if (!request.auth?.uid) throw new HttpsError('unauthenticated','Giriş gerekli.'); return request.auth.uid; }
function clean(v,n=200){return String(v||'').trim().slice(0,n)}
function isPremium(d){const now=Date.now(),trialUntil=d.premiumTrialUntil?.toMillis?.()||0,adminUntil=d.adminPremiumUntil?.toMillis?.()||0;return d.subscriptionStatus==='active'||(d.premiumTrialStatus==='active'&&trialUntil>now)||(d.adminPremiumStatus==='active'&&adminUntil>now)}
async function claimFor(db,venueKey){const s=await db.collection('business_claims').doc(venueKey).get();return{s,data:s.data()||{}}}
async function owner(request,venueKey,{premium=false,adminRead=false}={}){const uid=auth(request),db=getFirestore(),[c,v]=await Promise.all([claimFor(db,venueKey),db.collection('business_venues').doc(venueKey).get()]),d=c.data,venue=v.data()||{},ownsClaim=d.status==='verified'&&d.applicantUid===uid,ownsVenue=venue.verified===true&&venue.ownerUid===uid,isNamedAdmin=request.auth?.token?.admin===true&&String(request.auth?.token?.email||'').toLowerCase()==='turgutburaktan@gmail.com';if(!ownsClaim&&!ownsVenue&&!(adminRead&&isNamedAdmin))throw new HttpsError('permission-denied','Doğrulanmış işletme sahibi gerekli.');if(premium&&!isPremium(d)&&!isPremium(venue))throw new HttpsError('failed-precondition','Bu özellik TBT Business Premium gerektiriyor.');return{uid,db,claim:d,venue}}

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
  const venueKey=clean(request.data?.venueKey,240),{db}=await owner(request,venueKey,{adminRead:true}),base=db.collection('business_venues').doc(venueKey),venue=await base.get(),venueData=venue.data()||{};
  const boostId=clean(venueData.activeBoostId,180);
  const [metrics,days,followers,reservations,boost]=await Promise.all([
    base.collection('metrics').get().catch(error=>{console.error('dashboard metrics',error);return{docs:[]};}),
    base.collection('metric_days').orderBy(FieldPath.documentId(),'desc').limit(7).get().catch(error=>{console.error('dashboard days',error);return{docs:[]};}),
    base.collection('followers').count().get().catch(error=>{console.error('dashboard followers',error);return{data:()=>({count:0})};}),
    base.collection('reservations').orderBy('createdAt','desc').limit(100).get(),
    boostId?base.collection('boosts').doc(boostId).get().catch(error=>{console.error('dashboard boost',error);return null;}):Promise.resolve(null)
  ]);
  const out={};metrics.docs.forEach(d=>out[d.id]=Number(d.data().count||0));
  const daily=days.docs.map(doc=>({date:doc.id,...doc.data()}));
  await Promise.all(reservations.docs.filter(d=>d.data().status==='accepted'&&(d.data().orderItems||[]).length&&!d.data().preparationConfirmedAt&&d.data().at?.toMillis?.()>Date.now()).map(d=>syncReminder(db,d.ref)));
  const profiles=new Map();
  await Promise.all([...new Set(reservations.docs.filter(d=>!d.data().customerName).map(d=>d.data().userUid).filter(Boolean))].map(async uid=>{const profile=await db.collection('users').doc(uid).get();profiles.set(uid,profile.data()||{});}));
  const reservationItems=reservations.docs.map(doc=>reservationView(doc,venueKey,profiles.get(doc.data().userUid)));

  const histories=new Map();
  await Promise.all([...new Set(reservationItems.filter(r=>r.status==='pending'||r.status==='accepted').map(r=>r.userUid).filter(Boolean))].map(async uid=>histories.set(uid,await customerHistory(db,uid))));
  reservationItems.forEach(r=>{r.customerHistory=histories.get(r.userUid)||{prepared:0,cancelled:0,noShows:0};});
  const boostData=boost?.exists?boost.data()||{}:null;
  return{metrics:out,daily,followers:followers.data().count,reservations:reservationItems,boost:boostData?{id:boost.id,targetType:clean(boostData.targetType,30),targetId:clean(boostData.targetId,180),status:clean(boostData.status,20),startsAtMs:boostData.startsAt?.toMillis?.()||0,endsAtMs:boostData.endsAt?.toMillis?.()||0,impressions:Number(boostData.impressions||0),clicks:Number(boostData.clicks||0)}:null};
});

exports.requestBusinessReservation = onCall({region:'europe-west1'}, async request=>{
  const uid=auth(request),venueKey=clean(request.data?.venueKey,240),partySize=Number(request.data?.partySize||0),atMs=Number(request.data?.atMs||0),note=clean(request.data?.note,500);
  if(!venueKey||venueKey.includes('/')||!Number.isInteger(partySize)||partySize<1||partySize>50||!Number.isFinite(atMs)||atMs<=Date.now())throw new HttpsError('invalid-argument','Rezervasyon bilgileri geçersiz.');
  const contactPhone=clean(request.data?.contactPhone,40),selection=orderSelection(request.data?.orderItems);
  if(contactPhone&&!/^\+?[0-9 ()-]{8,30}$/.test(contactPhone))throw new HttpsError('invalid-argument','Geçerli telefon numarası gir.');
  const requestId=clean(request.data?.requestId,80);
  if(requestId&&!/^[A-Za-z0-9-]{12,80}$/.test(requestId))throw new HttpsError('invalid-argument','Talep kimliği geçersiz.');
  const db=getFirestore(),base=db.collection('business_venues').doc(venueKey),profile=await db.collection('users').doc(uid).get();
  const customerName=clean(request.data?.customerName||profile.data()?.displayName||profile.data()?.name||request.auth.token?.name)||'İsim belirtilmedi';
  const ref=requestId?base.collection('reservations').doc(createHash('sha256').update(uid+':'+requestId).digest('hex')):base.collection('reservations').doc();
  return db.runTransaction(async tx=>{
    const existing=await tx.get(ref);if(existing.exists)return {id:ref.id,status:existing.data().status};
    const venue=await tx.get(base);if(!venue.exists||venue.data().verified!==true)throw new HttpsError('failed-precondition','İşletme doğrulanmamış.');
    const recent=await tx.get(base.collection('reservations').where('userUid','==',uid));
    if(recent.docs.filter(d=>d.data().status==='pending').length>=3)throw new HttpsError('resource-exhausted','Bu işletmede üç bekleyen rezervasyonun var.');
    const menuDocs=await Promise.all(selection.map(x=>tx.get(base.collection('menu').doc(x.itemId))));
    const orderItems=pricedOrder(selection,menuDocs),orderTotalMinor=orderItems.reduce((sum,x)=>sum+x.totalMinor,0);
    tx.set(ref,{userUid:uid,customerName,contactPhone,venueName:clean(venue.data().venueName||venue.data().name),partySize,at:Timestamp.fromMillis(atMs),note,orderItems,orderTotalMinor,status:'pending',createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    return {id:ref.id,status:'pending'};
  });
});
exports.getMyBusinessReservations=onCall({region:'europe-west1'},async request=>{
  const uid=auth(request),db=getFirestore();
  let query=db.collectionGroup('reservations').where('userUid','==',uid).orderBy('at','desc').limit(100);
  if(request.data?.cursor){
    const cursor=String(request.data.cursor);
    if(!/^business_venues\/[^/]{1,240}\/reservations\/[^/]{1,180}$/.test(cursor))throw new HttpsError('invalid-argument','Geçersiz sayfa.');
    const previous=await db.doc(cursor).get();
    if(!previous.exists||previous.data().userUid!==uid)throw new HttpsError('permission-denied','Bu kayda erişimin yok.');
    query=query.startAfter(previous);
  }
  const snap=await query.get();
  const rows=await Promise.all(snap.docs.filter(d=>d.ref.parent.parent?.parent.id==='business_venues').map(async d=>{
    const base=d.ref.parent.parent,result=reservationView(d,base.id);
    if(result.status==='accepted'&&result.orderItems.length&&!result.preparationConfirmedAtMs&&result.atMs>Date.now())await syncReminder(db,d.ref);
    if(!result.venueName){const venue=await base.get();result.venueName=clean(venue.data()?.venueName||venue.data()?.name)||'İşletme';}
    return result;
  }));
  return {reservations:rows,nextCursor:snap.docs.length===100?snap.docs.at(-1).ref.path:null};
});
exports.respondBusinessReservation = onCall({region:'europe-west1'}, async request=>{
  const venueKey=clean(request.data?.venueKey,240),reservationId=clean(request.data?.reservationId,180),decision=clean(request.data?.decision,20),{db}=await owner(request,venueKey);
  if(!['accepted','rejected'].includes(decision))throw new HttpsError('invalid-argument','Geçersiz karar.');
  const ref=db.collection('business_venues').doc(venueKey).collection('reservations').doc(reservationId);
  await db.runTransaction(async tx=>{const snap=await tx.get(ref);if(!snap.exists)throw new HttpsError('not-found','Rezervasyon bulunamadı.');if(snap.data().status!=='pending')throw new HttpsError('failed-precondition','Bu rezervasyon zaten sonuçlandırılmış.');tx.update(ref,{status:decision,updatedAt:FieldValue.serverTimestamp()});});
  return {status:decision};
});

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
