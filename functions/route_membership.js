const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
exports.leaveTravelPlan=onCall({region:'europe-west1'},async request=>{
  const uid=request.auth?.uid,id=request.data?.planId;
  if(!uid)throw new HttpsError('unauthenticated','Giriş gerekli.');
  if(typeof id!=='string'||!id||id.includes('/')||id.length>200)throw new HttpsError('invalid-argument','Geçerli rota seç.');
  const db=getFirestore(),ref=db.doc(`travel_plans/${id}`);
  return db.runTransaction(async tx=>{
    const snap=await tx.get(ref),d=snap.data();
    if(!d)return {left:true};
    if(d.ownerId===uid)throw new HttpsError('failed-precondition','Rota sahibi ayrılmak yerine rotayı silebilir.');
    if(!(d.memberIds||[]).includes(uid))return {left:true};
    tx.update(ref,{memberIds:FieldValue.arrayRemove(uid),updatedAt:FieldValue.serverTimestamp()});
    tx.delete(ref.collection('members').doc(uid));
    return {left:true};
  });
});
