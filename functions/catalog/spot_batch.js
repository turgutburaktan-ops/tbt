const {FieldValue}=require('firebase-admin/firestore');
const {spotRow,partition}=require('./schema');
async function projectSpots(db,ids){
  if(ids.length>80)throw Error('Spot batch too large');if(!ids.length)return;
  await db.runTransaction(async tx=>{
    const docs=await tx.getAll(...ids.flatMap(id=>[db.doc(`photo_spots/${id}`),db.doc(`catalog_links/spot:${id}`)]));
    const changes=[],keys=new Set();
    for(let i=0;i<ids.length;i++){
      const id=`spot:${ids[i]}`,row=spotRow(ids[i],docs[i*2].data()),link=docs[i*2+1].data();
      const old=link?.partition||null,next=row?partition(row.city,'gezi'):null,serialized=row?JSON.stringify(row):null;
      if(link?.serialized===serialized&&old===next)continue;
      if(old)keys.add(old);if(next)keys.add(next);changes.push({id,row,old,next,serialized});
    }
    const list=[...keys],metaDocs=list.length?await tx.getAll(...list.map(k=>db.doc(`place_catalog/${k}`))):[];
    const metas=new Map(list.map((k,i)=>[k,{...(metaDocs[i].data()||{})}]));
    for(const c of changes){
      if(c.old&&c.old!==c.next){tx.delete(db.doc(`place_catalog/${c.old}/items/${c.id}`));const m=metas.get(c.old);m.count=Math.max(0,(m.count||0)-1);}
      if(c.row){
        tx.set(db.doc(`place_catalog/${c.next}/items/${c.id}`),{...c.row,updatedAt:FieldValue.serverTimestamp()});
        tx.set(db.doc(`catalog_links/${c.id}`),{partition:c.next,serialized:c.serialized});
        const r=c.row,m=metas.get(c.next);
        Object.assign(m,{schemaVersion:1,city:r.city,kind:'gezi',count:(m.count||0)+(c.old===c.next?0:1),
          minLatitude:Math.min(m.minLatitude??r.latitude,r.latitude),maxLatitude:Math.max(m.maxLatitude??r.latitude,r.latitude),
          minLongitude:Math.min(m.minLongitude??r.longitude,r.longitude),maxLongitude:Math.max(m.maxLongitude??r.longitude,r.longitude)});
      }else tx.delete(db.doc(`catalog_links/${c.id}`));
    }
    for(const [key,meta] of metas)tx.set(db.doc(`place_catalog/${key}`),{...meta,updatedAt:FieldValue.serverTimestamp()},{merge:true});
  });
}
module.exports={projectSpots};
