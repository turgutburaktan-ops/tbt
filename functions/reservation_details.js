const {HttpsError} = require('firebase-functions/v2/https');
const clean=(v,n=160)=>String(v||'').trim().slice(0,n);
function orderSelection(raw) {
  if(raw===undefined)return [];
  if(!Array.isArray(raw)||raw.length>20)throw new HttpsError('invalid-argument','En fazla 20 farklı ürün seç.');
  const seen=new Set();
  return raw.map(x=>{
    const itemId=clean(x?.itemId,180),quantity=Number(x?.quantity);
    if(!itemId||itemId.includes('/')||seen.has(itemId)||!Number.isInteger(quantity)||quantity<1||quantity>20)
      throw new HttpsError('invalid-argument','Ürün ve adet bilgileri geçersiz.');
    seen.add(itemId);return {itemId,quantity,...(x.expectedUnitPriceMinor===undefined?{}:{expectedUnitPriceMinor:Number(x.expectedUnitPriceMinor)})};
  });
}
function pricedOrder(selection,documents) {
  return selection.map((x,i)=>{
    const snap=documents[i],d=snap?.data()||{};
    if(!snap?.exists||d.available===false||d.active===false)throw new HttpsError('failed-precondition','Seçtiğin ürün artık mevcut değil. Menüyü yeniden aç.');
    const unitPriceMinor=d.priceMinor!==undefined?Number(d.priceMinor):Math.round(Number(d.price)*100);
    if(!Number.isSafeInteger(unitPriceMinor)||unitPriceMinor<0||unitPriceMinor>100000000)
      throw new HttpsError('failed-precondition','Bu ürünün fiyatı henüz belirlenmemiş.');
    if(x.expectedUnitPriceMinor!==undefined&&x.expectedUnitPriceMinor!==unitPriceMinor)throw new HttpsError('failed-precondition','Ürün fiyatı değişti. Menüyü yeniden açıp siparişini kontrol et.');
    return {itemId:x.itemId,quantity:x.quantity,name:clean(d.name||d.title),unitPriceMinor,totalMinor:unitPriceMinor*x.quantity};
  });
}
function reservationView(doc,venueKey,profile={}) {
  const d=doc.data()||{};
  return {id:doc.id,venueKey,userUid:clean(d.userUid,180),venueName:clean(d.venueName),customerName:clean(d.customerName||profile.displayName||profile.name||profile.username)||'İsim belirtilmedi',contactPhone:clean(d.contactPhone,40),partySize:Number(d.partySize||0),atMs:d.at?.toMillis?.()||0,note:clean(d.note,500),status:clean(d.status,20),createdAtMs:d.createdAt?.toMillis?.()||0,orderItems:Array.isArray(d.orderItems)?d.orderItems:[],orderTotalMinor:Number(d.orderTotalMinor||0)};
}
module.exports={orderSelection,pricedOrder,reservationView};
