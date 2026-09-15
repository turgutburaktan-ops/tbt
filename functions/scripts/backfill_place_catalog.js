const {initializeApp} = require('firebase-admin/app');
const {getFirestore,FieldPath,FieldValue} = require('firebase-admin/firestore');
const {spotRow,venueRow,provinces,kinds,partition} = require('../catalog/schema');
const {project} = require('../catalog/store');
initializeApp();
const db=getFirestore(), apply=process.argv.includes('--apply');
async function scan(collection,fn){let cursor;while(true){let q=db.collection(collection).orderBy(FieldPath.documentId()).limit(200);if(cursor)q=q.startAfter(cursor);const page=await q.get();for(const d of page.docs)await fn(d);if(page.size<200)break;cursor=page.docs.at(-1).id;}}
(async()=>{
  const counts={mode:apply?'apply':'dry-run',spots:0,venues:0,invalidSpots:0,unpublishedOrIncompleteVenues:0};
  for(const [collection,type] of [['photo_spots','spot'],['business_venues','venue'],['catalog_external_venues','venue']]){
    await scan(collection,async doc=>{
      const row=type==='spot'?spotRow(doc.id,doc.data()):venueRow(doc.id,collection==='catalog_external_venues'?doc.data():null,collection==='business_venues'?doc.data():null);
      if(row)counts[type==='spot'?'spots':'venues']++;else counts[type==='spot'?'invalidSpots':'unpublishedOrIncompleteVenues']++;
      if(apply)await project(db,type,doc.id);
    });
  }
  if(apply){
    for(const city of provinces)for(const kind of kinds){
      const ref=db.doc(`place_catalog/${partition(city,kind)}`);
      await db.runTransaction(async tx=>{const old=(await tx.get(ref)).data()||{};tx.set(ref,{schemaVersion:1,city,kind,count:old.count||0,ready:true,sourceStatus:old.sourceStatus||(kind==='gezi'?'ready':'pending'),migratedAt:FieldValue.serverTimestamp()},{merge:true});});
    }
  }
  console.log(JSON.stringify(counts));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
