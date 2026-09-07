const {syncReminder}=require('./reservation_reminders');
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onDocumentWritten}=require('firebase-functions/v2/firestore');
const {onSchedule}=require('firebase-functions/v2/scheduler');
const {getFirestore,Timestamp,FieldValue}=require('firebase-admin/firestore');
const {createHash}=require('crypto');
const {transition,ms,MINUTE,DAY,PolicyError}=require('./reservation_policy');
const clean=(v,n=180)=>String(v||'').trim().slice(0,n);
const key=path=>createHash('sha256').update(path).digest('hex');
function signed(request){if(!request.auth?.uid)throw new HttpsError('unauthenticated','Giriş gerekli.');return request.auth.uid;}
function admin(request){signed(request);if(request.auth.token?.admin!==true||String(request.auth.token?.email||'').toLowerCase()!=='turgutburaktan@gmail.com')throw new HttpsError('permission-denied','Yönetici gerekli.');}
function reference(db,data){const venueKey=clean(data?.venueKey,240),id=clean(data?.reservationId);if(!venueKey||venueKey.includes('/')||!id||id.includes('/'))throw new HttpsError('invalid-argument','Rezervasyon gerekli.');return db.collection('business_venues').doc(venueKey).collection('reservations').doc(id);}
function notice(db,uid,id,ref,title,body,type='business_reservation_action'){
 return {ref:db.collection('users').doc(uid).collection('notifications').doc(id),data:{type,title,body,sourceId:ref.parent.parent.id,businessVenueKey:ref.parent.parent.id,contentId:ref.id,read:false,createdAt:FieldValue.serverTimestamp()}};
}
exports.syncBusinessPreparationReminder=onDocumentWritten({region:'europe-west1',document:'business_venues/{venueKey}/reservations/{reservationId}',retry:true},event=>syncReminder(getFirestore(),event.data.after.ref));
exports.sendBusinessPreparationReminders=onSchedule({region:'europe-west1',schedule:'every 1 minutes',timeZone:'Europe/Istanbul',retryCount:3},async()=>{
 const db=getFirestore();
 for(let batch=0;batch<5;batch++){
  const jobs=await db.collection('reservation_preparation_jobs').where('dueAt','<=',Timestamp.now()).orderBy('dueAt').limit(100).get();
  if(jobs.empty)break;
  await Promise.all(jobs.docs.map(d=>syncReminder(db,db.doc(d.data().reservationPath))));
 }
});
exports.reservationPreparationAction=onCall({region:'europe-west1'},async request=>{
 const uid=signed(request),db=getFirestore(),ref=reference(db,request.data),action=clean(request.data?.action,30),now=Date.now();
 return db.runTransaction(async tx=>{
  const snap=await tx.get(ref);if(!snap.exists)throw new HttpsError('not-found','Rezervasyon bulunamadı.');
  const r=snap.data(),venue=await tx.get(ref.parent.parent),ownerUid=venue.data()?.verified===true?venue.data().ownerUid:null;
  const customerActions=['confirm','cancel','reschedule','dispute'];
  const role=customerActions.includes(action)&&uid===r.userUid?'customer':!customerActions.includes(action)&&uid===ownerUid?'owner':null;
  if(!role)throw new HttpsError('permission-denied','Bu işlem için yetkin yok.');
  if(Number(request.data?.expectedAtMs)!==ms(r.at))throw new HttpsError('failed-precondition','Rezervasyon saati değişti. Listeyi yenile.');
  const historyRef=db.collection('users').doc(r.userUid).collection('reservation_history').doc(key(ref.path));
  const history=await tx.get(historyRef);
  if(action==='dispute'){
   const reason=clean(request.data?.reason,700),h=history.data();
   if(reason.length<5)throw new HttpsError('invalid-argument','İtiraz nedenini yaz.');
   if(!h||!['reported','cancelled'].includes(h.status)||ms(h.preparedAt)<now-90*DAY)throw new HttpsError('failed-precondition','Bu kayıt için itiraz açılamıyor.');
   tx.update(historyRef,{status:'disputed',originalStatus:h.status,reason,disputedAt:Timestamp.now()});
   tx.update(ref,{incidentStatus:'disputed',updatedAt:Timestamp.now()});
   tx.set(db.collection('reservation_disputes').doc(key(ref.path)),{reservationPath:ref.path,userUid:r.userUid,venueKey:ref.parent.parent.id,customerName:clean(r.customerName),reason,originalStatus:h.status,status:'disputed',venueName:clean(venue.data()?.venueName||venue.data()?.name),atMs:ms(r.at),confirmedAtMs:ms(r.preparationConfirmedAt),startedAtMs:ms(r.preparationStartedAt),createdAt:Timestamp.now()});
   return {ok:true};
  }
  let result;try{result=transition(r,action,role,now,Number(request.data?.atMs));}catch(error){if(error instanceof PolicyError)throw new HttpsError('failed-precondition',error.message);throw error;}
  if(result.noop)return {ok:true};
  const patch={...result.patch,updatedAt:Timestamp.now()};
  for(const field of ['at','preparationConfirmedAt','preparationStartedAt','cancelledAt','incidentReportedAt','incidentReviewAfter'])if(typeof patch[field]==='number')patch[field]=Timestamp.fromMillis(patch[field]);
  if(result.outcome==='cancelled'){patch.incidentStatus='cancelled';patch.incidentReportedAt=Timestamp.now();}
  if(result.outcome){
   const h={status:result.outcome,reservationPath:ref.path,venueKey:ref.parent.parent.id,updatedAt:Timestamp.now()};
   if(result.outcome==='prepared')h.preparedAt=Timestamp.now();
   if(result.outcome==='reported')h.reviewAfter=Timestamp.fromMillis(now+3*DAY);
   tx.set(historyRef,h,{merge:true});
  }
  tx.update(ref,patch);
  const recipient=role==='customer'?ownerUid:r.userUid;
  if(recipient){const n=notice(db,recipient,`reservation_${key(ref.path)}_${action}_${r.scheduleVersion||0}`,ref,result.notify,result.notify,role==='customer'?'business_reservation_owner_action':'business_reservation_action');tx.set(n.ref,n.data);}
  return {ok:true};
 });
});
exports.getReservationDisputes=onCall({region:'europe-west1'},async request=>{admin(request);const snap=await getFirestore().collection('reservation_disputes').where('status','==','disputed').limit(100).get();return {items:snap.docs.map(d=>({id:d.id,...d.data()}))};});
exports.resolveReservationDispute=onCall({region:'europe-west1'},async request=>{
 admin(request);const id=clean(request.data?.id),decision=clean(request.data?.decision),reason=clean(request.data?.reason,700);
 if(!/^[a-f0-9]{64}$/.test(id)||!['confirm','dismiss'].includes(decision)||reason.length<5)throw new HttpsError('invalid-argument','Karar ve gerekçe gerekli.');
 const db=getFirestore(),disputeRef=db.collection('reservation_disputes').doc(id);
 await db.runTransaction(async tx=>{
  const snap=await tx.get(disputeRef),d=snap.data();if(!d||d.status!=='disputed')throw new HttpsError('failed-precondition','İtiraz sonuçlandırılmış.');
  const ref=db.doc(d.reservationPath),historyRef=db.collection('users').doc(d.userUid).collection('reservation_history').doc(id);
  const r=await tx.get(ref);const h=await tx.get(historyRef);if(!r.exists||h.data()?.status!=='disputed')throw new HttpsError('failed-precondition','İtiraz kaydı değişti.');
  const status=decision==='dismiss'?'dismissed':d.originalStatus==='cancelled'?'confirmed_cancelled':'confirmed_no_show';
  tx.update(disputeRef,{status,decisionReason:reason,resolvedBy:request.auth.uid,resolvedAt:Timestamp.now()});tx.update(historyRef,{status});tx.update(ref,{incidentStatus:status,incidentResolution:reason});
  const n=notice(db,d.userUid,`dispute_result_${id}`,ref,'Rezervasyon itirazın sonuçlandı',reason);tx.set(n.ref,n.data);
 });return {ok:true};
});
