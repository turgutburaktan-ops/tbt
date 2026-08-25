const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

function clean(v,n=300){return String(v||'').trim().slice(0,n)}
function auth(r){if(!r.auth?.uid)throw new HttpsError('unauthenticated','Giriş gerekli.');return r.auth.uid}

exports.createBusinessCandidate = onCall({region:'europe-west1'}, async request=>{
  const uid=auth(request); const d=request.data||{};
  const category=clean(d.category,40), venueName=clean(d.venueName,180), address=clean(d.address,300), city=clean(d.city,100);
  const latitude=Number(d.latitude), longitude=Number(d.longitude);
  if(!['cafe','dining','hotel'].includes(category))throw new HttpsError('invalid-argument','İşletme kategorisi geçersiz.');
  if(venueName.length<3)throw new HttpsError('invalid-argument','İşletme adı çok kısa.');
  if(address.length<5)throw new HttpsError('invalid-argument','Adres bilgisi gerekli.');
  if(!Number.isFinite(latitude)||!Number.isFinite(longitude)||latitude < -90||latitude > 90||longitude < -180||longitude > 180){
    throw new HttpsError('invalid-argument','İşletme konumu gerekli. İşletmedeyken mevcut konumu kullanabilirsin.');
  }
  const db=getFirestore();
  const recent=await db.collection('business_venue_submissions').where('createdBy','==',uid).limit(20).get();
  const active=recent.docs.filter(x=>['candidate','pending_review'].includes(String(x.data().status||'')));
  if(active.length>=5)throw new HttpsError('resource-exhausted','Aynı anda en fazla 5 yeni işletme önerisi oluşturabilirsin.');
  const subRef=db.collection('business_venue_submissions').doc();
  const venueId=`user_${subRef.id}`; const venueKey=`${category}:${venueId}`;
  const payload={venueKey,venueId,category,venueName,address,city,latitude,longitude,source:'user_submission',listingStatus:'candidate',verified:false,pendingListing:true,createdBy:uid,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()};
  await Promise.all([
    subRef.set({...payload,status:'candidate'}),
    db.collection('business_venues').doc(venueKey).set(payload,{merge:true}),
  ]);
  return {venueId,venueKey,venueName,category,latitude,longitude};
});
