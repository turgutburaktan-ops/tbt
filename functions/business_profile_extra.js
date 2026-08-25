const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

function clean(v,n=300){return String(v||'').trim().slice(0,n)}
function key(c,v){return `${clean(c,40)}:${clean(v,180)}`}
function auth(r){if(!r.auth?.uid)throw new HttpsError('unauthenticated','Giriş gerekli.');return r.auth.uid}
async function owner(r,c,v){const uid=auth(r),db=getFirestore(),id=key(c,v);const s=await db.collection('business_claims').doc(id).get(),d=s.data()||{};if(d.status!=='verified'||d.applicantUid!==uid)throw new HttpsError('permission-denied','Doğrulanmış işletme sahibi gerekli.');return{uid,db,id}}

exports.updateBusinessMenuMedia = onCall({region:'europe-west1'}, async r=>{
  const d=r.data||{},ctx=await owner(r,d.category,d.venueId),itemId=clean(d.itemId,180),url=clean(d.imageUrl,1200),path=clean(d.storagePath,600);
  if(!itemId||!url||!path)throw new HttpsError('invalid-argument','Ürün görseli bilgileri eksik.');
  const expected=`users/${ctx.uid}/business_profiles/${ctx.id}/menu/${itemId}.jpg`;
  if(path!==expected)throw new HttpsError('permission-denied','Ürün görseli yolu geçersiz.');
  const file=getStorage().bucket().file(path);const [exists]=await file.exists();if(!exists)throw new HttpsError('failed-precondition','Ürün görseli bulunamadı.');
  const [meta]=await file.getMetadata();const size=Number(meta.size||0),type=String(meta.contentType||'').toLowerCase();if(size<=0||size>10*1024*1024||!['image/jpeg','image/png','image/webp'].includes(type))throw new HttpsError('invalid-argument','Ürün görseli türü veya boyutu geçersiz.');
  const ref=ctx.db.collection('business_venues').doc(ctx.id).collection('menu').doc(itemId);if(!(await ref.get()).exists)throw new HttpsError('not-found','Menü ürünü bulunamadı.');
  await ref.update({imageUrl:url,imageStoragePath:path,updatedAt:FieldValue.serverTimestamp(),updatedBy:ctx.uid});return{ok:true};
});
