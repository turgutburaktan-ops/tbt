const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

function clean(v,n=300){return String(v||'').trim().slice(0,n)}
function key(c,v){return `${clean(c,40)}:${clean(v,180)}`}
function auth(request){if(!request.auth?.uid)throw new HttpsError('unauthenticated','Giriş gerekli.');return request.auth.uid}
async function owner(request,category,venueId){const uid=auth(request),db=getFirestore(),id=key(category,venueId),s=await db.collection('business_claims').doc(id).get(),d=s.data()||{};if(d.status!=='verified'||d.applicantUid!==uid)throw new HttpsError('permission-denied','Yalnız doğrulanmış işletme sahibi bu işlemi yapabilir.');return{uid,db,id}}

exports.addBusinessMenuItem = onCall({region:'europe-west1'}, async request=>{
  const d=request.data||{}; const {uid,db,id}=await owner(request,d.category,d.venueId);
  const name=clean(d.name,120), section=clean(d.section,80), description=clean(d.description,500), priceMinor=Number(d.priceMinor||0), available=d.available!==false;
  if(!name||!section||!Number.isInteger(priceMinor)||priceMinor<0||priceMinor>100000000)throw new HttpsError('invalid-argument','Menü bilgileri geçersiz.');
  const venueRef=db.collection('business_venues').doc(id); await venueRef.set({ownerUid:uid,verified:true,updatedAt:FieldValue.serverTimestamp()},{merge:true});
  const ref=await venueRef.collection('menu').add({name,section,description,priceMinor,currency:'TRY',active:true,available,createdBy:uid,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
  return{ok:true,itemId:ref.id};
});

exports.updateBusinessWeeklyHours = onCall({region:'europe-west1'}, async request=>{
  const d=request.data||{}; const {uid,db,id}=await owner(request,d.category,d.venueId); const input=d.weeklyHours;
  if(!input||typeof input!=='object'||Array.isArray(input))throw new HttpsError('invalid-argument','Çalışma saatleri geçersiz.');
  const days=['mon','tue','wed','thu','fri','sat','sun']; const out={};
  for(const day of days){const row=input[day]||{};const closed=row.closed===true;const open=clean(row.open,5),close=clean(row.close,5);if(!closed&&(!/^([01]\d|2[0-3]):[0-5]\d$/.test(open)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(close)))throw new HttpsError('invalid-argument',`${day} çalışma saati geçersiz.`);out[day]={closed,open:closed?'':open,close:closed?'':close};}
  await db.collection('business_venues').doc(id).set({ownerUid:uid,verified:true,weeklyHours:out,updatedAt:FieldValue.serverTimestamp()},{merge:true});
  return{ok:true};
});
