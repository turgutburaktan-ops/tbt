'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {createHash}=require('crypto');
const digest=value=>createHash('sha256').update(value).digest('hex');
const key=row=>[row.section,row.name].map(x=>String(x||'').trim().replace(/\s+/g,' ').toLocaleLowerCase('tr-TR')).join('\u0000');
function validateRows(rows){
  if(!Array.isArray(rows)||rows.length<1||rows.length>100)throw new HttpsError('invalid-argument','Bir seferde 1–100 ürün ekleyebilirsin.');
  return rows.map((row,i)=>{
    const name=String(row?.name||'').trim(),section=String(row?.section||'').trim(),description=String(row?.description||'').trim(),priceMinor=row?.priceMinor;
    if(!name||name.length>120||!section||section.length>80||description.length>500||!Number.isSafeInteger(priceMinor)||priceMinor<0||priceMinor>100000000||typeof row.available!=='boolean')throw new HttpsError('invalid-argument',`${i+1}. satırdaki ürün adı, bölüm, fiyat veya açıklama geçersiz.`);
    return{name,section,description,priceMinor,available:row.available};
  });
}
exports.addBusinessMenuItemsBulk=onCall({region:'europe-west1'},async request=>{
  const uid=request.auth?.uid;if(!uid)throw new HttpsError('unauthenticated','Giriş gerekli.');
  const d=request.data||{},venueKey=String(d.venueKey||''),requestId=String(d.requestId||'');
  if(!venueKey||venueKey.length>240||venueKey.includes('/')||!/^[a-zA-Z0-9-]{12,80}$/.test(requestId))throw new HttpsError('invalid-argument','İşletme veya işlem kimliği geçersiz.');
  const rows=validateRows(d.items),payloadHash=digest(JSON.stringify(rows)),db=getFirestore(),base=db.collection('business_venues').doc(venueKey),importId=digest(uid+':'+requestId),receipt=base.collection('menu_imports').doc(importId);
  return db.runTransaction(async tx=>{
    const [venue,claim,previous]=await Promise.all([tx.get(base),tx.get(db.collection('business_claims').doc(venueKey)),tx.get(receipt)]);
    const v=venue.data()||{},c=claim.data()||{};
    if(!((v.verified===true&&v.ownerUid===uid)||(c.status==='verified'&&c.applicantUid===uid)))throw new HttpsError('permission-denied','Doğrulanmış işletme sahibi gerekli.');
    if(previous.exists){if(previous.data().payloadHash!==payloadHash)throw new HttpsError('failed-precondition','Bu işlem daha önce farklı satırlarla kaydedilmiş. Önce menüyü yenile.');return previous.data().result;}
    const existing=await tx.get(base.collection('menu'));
    const seen=new Set(existing.docs.map(doc=>key(doc.data()))),added=[],skipped=[];
    rows.forEach((row,index)=>{
      const identity=key(row);if(seen.has(identity)){skipped.push({row:index+1,name:row.name,section:row.section});return;}
      seen.add(identity);const itemId='bulk_'+digest(importId+':'+index);
      tx.set(base.collection('menu').doc(itemId),{...row,currency:'TRY',active:true,createdBy:uid,createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp(),importId});added.push(itemId);
    });
    const result={ok:true,addedCount:added.length,skippedCount:skipped.length,skipped,itemIds:added};
    tx.set(base,{ownerUid:uid,verified:true,updatedAt:FieldValue.serverTimestamp()},{merge:true});
    tx.set(receipt,{uid,payloadHash,result,createdAt:FieldValue.serverTimestamp()});
    return result;
  });
});
