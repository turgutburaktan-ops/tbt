// Bounded atomic import: source + public projection + identity link + counts.
// This avoids tens of thousands of sequential per-record network transactions.
const {FieldValue} = require('firebase-admin/firestore');
const {venueRow, partition} = require('./schema');
async function seedRows(db, input) {
  if(input.length>80)throw Error('Seed chunk exceeds transaction bound');
  return db.runTransaction(async tx=>{
    const refs=input.flatMap(r=>{
      const key=`${r.category}:${r.venueId}`, id=`venue:${key}`;
      return [db.doc(`catalog_links/${id}`),db.doc(`business_venues/${key}`),db.doc(`catalog_exclusions/${id}`),db.doc(`catalog_external_venues/${key}`)];
    });
    const docs=await tx.getAll(...refs), changes=[], metaKeys=new Set();
    for(let i=0;i<input.length;i++){
      const incoming=input[i],key=`${incoming.category}:${incoming.venueId}`,id=`venue:${key}`;
      const link=docs[i*4].data(),business=docs[i*4+1].data(),exclusion=docs[i*4+2].exists;
      // Keep already imported live data; the country snapshot only fills gaps.
      const external=docs[i*4+3].data()||incoming;
      const previous=link?.serialized?JSON.parse(link.serialized):null;
      const revoked=previous?.managed===true && business?.verified!==true;
      const row=venueRow(key,external,business,exclusion||revoked);
      const next=row?partition(row.city,row.kind):null, old=link?.partition||null;
      if(old)metaKeys.add(old);if(next)metaKeys.add(next);
      changes.push({incoming,key,id,link,row,next,old,revoked,hasExternal:docs[i*4+3].exists});
    }
    const keys=[...metaKeys], metas=keys.length?await tx.getAll(...keys.map(k=>db.doc(`place_catalog/${k}`))):[];
    const metadata=new Map(keys.map((k,i)=>[k,{...(metas[i].data()||{})}]));
    for(const c of changes){
      if(!c.hasExternal)tx.set(db.doc(`catalog_external_venues/${c.key}`),{...c.incoming,seenAt:FieldValue.serverTimestamp(),seedSource:'geofabrik'});
      if(c.revoked)tx.set(db.doc(`catalog_exclusions/${c.id}`),{reason:'business_unpublished',at:FieldValue.serverTimestamp()});
      const serialized=c.row?JSON.stringify(c.row):null;
      if(c.link?.serialized===serialized && c.old===c.next)continue;
      if(c.old && c.old!==c.next){
        tx.delete(db.doc(`place_catalog/${c.old}/items/${c.id}`));
        const m=metadata.get(c.old);m.count=Math.max(0,(m.count||0)-1);
      }
      if(c.row){
        tx.set(db.doc(`place_catalog/${c.next}/items/${c.id}`),{...c.row,updatedAt:FieldValue.serverTimestamp()});
        tx.set(db.doc(`catalog_links/${c.id}`),{partition:c.next,serialized});
        const m=metadata.get(c.next),r=c.row;
        Object.assign(m,{city:r.city,kind:r.kind,schemaVersion:1,count:(m.count||0)+(c.old===c.next?0:1),
          minLatitude:Math.min(m.minLatitude??r.latitude,r.latitude),maxLatitude:Math.max(m.maxLatitude??r.latitude,r.latitude),
          minLongitude:Math.min(m.minLongitude??r.longitude,r.longitude),maxLongitude:Math.max(m.maxLongitude??r.longitude,r.longitude)});
      }else tx.delete(db.doc(`catalog_links/${c.id}`));
    }
    for(const [key,meta] of metadata)tx.set(db.doc(`place_catalog/${key}`),{...meta,updatedAt:FieldValue.serverTimestamp()},{merge:true});
  });
}
module.exports={seedRows};
