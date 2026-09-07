const {Timestamp,FieldValue}=require('firebase-admin/firestore');
const {createHash}=require('crypto');
const {ms,MINUTE}=require('./reservation_policy');
const key=path=>createHash('sha256').update(path).digest('hex');
function notice(db,uid,id,ref,title,body,type='business_reservation_action'){
 return {ref:db.collection('users').doc(uid).collection('notifications').doc(id),data:{type,title,body,sourceId:ref.parent.parent.id,businessVenueKey:ref.parent.parent.id,contentId:ref.id,read:false,createdAt:FieldValue.serverTimestamp()}};
}
async function syncReminder(db,ref){
 const jobRef=db.collection('reservation_preparation_jobs').doc(key(ref.path));
 return db.runTransaction(async tx=>{
  const snap=await tx.get(ref);if(!snap.exists){tx.delete(jobRef);return;}
  const r=snap.data(),at=ms(r.at),now=Date.now(),version=r.scheduleVersion||0;
  if(r.status!=='accepted'||!(r.orderItems||[]).length||r.preparationConfirmedAt||now>=at+30*MINUTE){tx.delete(jobRef);return;}
  const n=notice(db,r.userUid,`preparation_${key(ref.path)}_${at}_${version}`,ref,'Rezervasyonun yaklaştı','Planında değişiklik yoksa siparişinin hazırlığına başlayalım mı? Uygulamada veya trtbt.com’da Rezervasyonlarım bölümünden yanıtla.','business_preparation_reminder');
  const existing=await tx.get(n.ref);
  if(existing.exists){tx.delete(jobRef);return;}
  if(now>=at-15*MINUTE){tx.create(n.ref,n.data);tx.update(ref,{reminderSentAt:FieldValue.serverTimestamp()});tx.delete(jobRef);}
  else tx.set(jobRef,{reservationPath:ref.path,dueAt:Timestamp.fromMillis(at-15*MINUTE),atMs:at,version});
 });
}
module.exports={syncReminder};
