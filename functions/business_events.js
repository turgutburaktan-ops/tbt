const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {getFirestore,Timestamp,FieldValue,GeoPoint}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const clean=v=>typeof v==='string'?v.trim():'';
exports.createBusinessEvent=onCall({region:'europe-west1'},async request=>{
  const uid=request.auth?.uid,d=request.data||{},key=clean(d.venueKey),requestId=clean(d.requestId);
  if(!uid)throw new HttpsError('unauthenticated','Giriş gerekli.');
  if(!/^(cafe|dining|hotel):[^/\s]{1,180}$/.test(key)||!/^[a-zA-Z0-9-]{12,80}$/.test(requestId))throw new HttpsError('invalid-argument','İşletme veya işlem kimliği geçersiz.');
  const db=getFirestore(),base=db.doc(`business_venues/${key}`),eventId='business_'+createHash('sha256').update(uid+':'+key+':'+requestId).digest('hex'),event=db.doc(`social_events/${eventId}`);
  return db.runTransaction(async tx=>{
    const [venue,claim,previous]=await Promise.all([tx.get(base),tx.get(db.doc(`business_claims/${key}`)),tx.get(event)]),v=venue.data()||{},c=claim.data()||{};
    if(!((v.verified===true&&v.ownerUid===uid)||(c.status==='verified'&&c.applicantUid===uid)))throw new HttpsError('permission-denied','Yalnız doğrulanmış işletme sahibi etkinlik oluşturabilir.');
    if(previous.exists)return {eventId};
    const title=clean(d.title),city=clean(d.city),description=clean(d.description),locationLabel=clean(d.locationLabel),type=clean(d.type),starts=Number(d.startsAtMs),capacity=d.capacity,lat=d.latitude,lng=d.longitude;
    if(title.length<3||title.length>160||!city||!locationLabel||description.length>5000||!Number.isFinite(starts)||starts<Date.now()+15*60000||!Number.isInteger(capacity)||capacity<1||capacity>10000||typeof lat!=='number'||typeof lng!=='number'||!Number.isFinite(lat)||!Number.isFinite(lng)||Math.abs(lat)>90||Math.abs(lng)>180)throw new HttpsError('invalid-argument','Başlık, tarih, kapasite ve konum bilgilerini kontrol et.');
    if(!['photography','cycling','running','walking','hiking','camping','followerMeetup','trip','social','concert','party','theatre','seminar','workshop','festival','talk','exhibition','standUp','dance','cinema','gaming','foodDrink','networking','education','charity','other'].includes(type)||(type==='other'&&clean(d.customTypeLabel).length<3))throw new HttpsError('invalid-argument','Etkinlik türünü seç.');
    const data={id:eventId,title,description,city,locationLabel,type,customTypeLabel:clean(d.customTypeLabel),hostId:uid,hostName:clean(v.venueName||v.name)||clean(c.venueName),businessVenueKey:key,businessVenueId:key.slice(key.indexOf(':')+1),businessCategory:key.split(':')[0],
      startsAt:Timestamp.fromMillis(starts),capacity,participantIds:[uid],latitude:lat,longitude:lng,location:new GeoPoint(lat,lng),status:'open',visibility:'public',allowedUserIds:[],approximateLocationOnly:false,accessType:'free',ticketPriceMinor:0,currency:'TRY',paymentStatus:'notRequired',salesStatus:'not_required',trustStatus:'verified_business',createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()};
    tx.create(event,data);
    tx.create(base.collection('program').doc(eventId),{title,description,startsAt:data.startsAt,socialEventId:eventId,active:true,createdBy:uid,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    return {eventId};
  });
});
