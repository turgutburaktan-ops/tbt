const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

function clean(v,n=300){return String(v||'').trim().slice(0,n)}
function auth(r){if(!r.auth?.uid)throw new HttpsError('unauthenticated','Giriş gerekli.');return r.auth.uid}
function normalizedName(v){return clean(v,180).toLocaleLowerCase('tr-TR').replace(/[^a-z0-9çğıöşü]+/gi,' ').replace(/\s+/g,' ').trim()}
function distanceMeters(lat1,lon1,lat2,lon2){
  const r=6371000,toRad=x=>x*Math.PI/180;
  const dLat=toRad(lat2-lat1),dLon=toRad(lon2-lon1);
  const a=Math.sin(dLat/2)**2+Math.cos(toRad(lat1))*Math.cos(toRad(lat2))*Math.sin(dLon/2)**2;
  return 2*r*Math.atan2(Math.sqrt(a),Math.sqrt(1-a));
}

exports.createBusinessCandidate = onCall({region:'europe-west1'}, async request=>{
  const uid=auth(request); const d=request.data||{};
  const category=clean(d.category,40), venueName=clean(d.venueName,180), address=clean(d.address,300), city=clean(d.city,100);
  const latitude=Number(d.latitude), longitude=Number(d.longitude); const normalized=normalizedName(venueName);
  if(!['cafe','dining','hotel'].includes(category))throw new HttpsError('invalid-argument','İşletme kategorisi geçersiz.');
  if(venueName.length<3||normalized.length<3)throw new HttpsError('invalid-argument','İşletme adı çok kısa.');
  if(address.length<5)throw new HttpsError('invalid-argument','Adres bilgisi gerekli.');
  if(!Number.isFinite(latitude)||!Number.isFinite(longitude)||latitude < -90||latitude > 90||longitude < -180||longitude > 180){
    throw new HttpsError('invalid-argument','İşletme konumu gerekli. İşletmedeyken mevcut konumu kullanabilirsin.');
  }

  const db=getFirestore();
  const recentMine=await db.collection('business_venue_submissions').where('createdBy','==',uid).limit(30).get();
  const active=recentMine.docs.filter(x=>['candidate','pending_review'].includes(String(x.data().status||'')));
  if(active.length>=5)throw new HttpsError('resource-exhausted','Aynı anda en fazla 5 yeni işletme önerisi oluşturabilirsin.');

  const recentAll=await db.collection('business_venue_submissions').orderBy('createdAt','desc').limit(300).get();
  const duplicate=recentAll.docs.find(doc=>{
    const x=doc.data()||{};
    if(!['candidate','pending_review','published'].includes(String(x.status||'')))return false;
    if(String(x.category||'')!==category)return false;
    const otherName=normalizedName(x.normalizedName||x.venueName||'');
    if(otherName!==normalized)return false;
    const lat=Number(x.latitude),lon=Number(x.longitude);
    return Number.isFinite(lat)&&Number.isFinite(lon)&&distanceMeters(latitude,longitude,lat,lon)<=500;
  });
  if(duplicate){
    const existing=duplicate.data()||{};
    if(existing.createdBy===uid){
      return {venueId:existing.venueId,venueKey:existing.venueKey,venueName:existing.venueName,category:existing.category,latitude:existing.latitude,longitude:existing.longitude,existing:true};
    }
    throw new HttpsError('already-exists','Bu işletme daha önce TBT’ye önerilmiş. Mevcut işletme kaydını kullanabilirsin.');
  }

  const subRef=db.collection('business_venue_submissions').doc();
  const venueId=`user_${subRef.id}`; const venueKey=`${category}:${venueId}`;
  const payload={venueKey,venueId,category,venueName,normalizedName:normalized,address,city,latitude,longitude,source:'user_submission',listingStatus:'candidate',verified:false,pendingListing:true,createdBy:uid,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()};
  await Promise.all([
    subRef.set({...payload,status:'candidate'}),
    db.collection('business_venues').doc(venueKey).set(payload,{merge:true}),
  ]);
  return {venueId,venueKey,venueName,category,latitude,longitude,existing:false};
});
