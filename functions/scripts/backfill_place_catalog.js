const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldPath,FieldValue}=require('firebase-admin/firestore');
const {spotRow,venueRow,provinces,kinds,partition}=require('../catalog/schema');
const {project}=require('../catalog/store');
const {projectSpots}=require('../catalog/spot_batch');
initializeApp();const db=getFirestore(),apply=process.argv.includes('--apply');
async function parallel(items,fn,size=6){for(let i=0;i<items.length;i+=size)await Promise.all(items.slice(i,i+size).map(fn));}
(async()=>{
  const counts={mode:apply?'apply':'dry-run',spots:0,venues:0,invalidSpots:0,unpublishedOrIncompleteVenues:0,alreadyProjected:0};
  // External imports already publish atomically or through retryable triggers.
  // Do not rescan a growing import while reconciling the original application.
  const sources=[['photo_spots','spot'],['business_venues','venue']];
  if(process.argv.includes('--include-external'))sources.push(['catalog_external_venues','venue']);
  for(const [collection,type] of sources){
    let cursor;
    while(true){
      let q=db.collection(collection).orderBy(FieldPath.documentId()).limit(200);if(cursor)q=q.startAfter(cursor);
      const page=await q.get();if(page.empty)break;
      const links=apply&&type==='spot'?await db.getAll(...page.docs.map(d=>db.doc(`catalog_links/spot:${d.id}`))):[];
      const pending=[];
      for(let i=0;i<page.docs.length;i++){
        const doc=page.docs[i],row=type==='spot'?spotRow(doc.id,doc.data()):venueRow(doc.id,collection==='catalog_external_venues'?doc.data():null,collection==='business_venues'?doc.data():null);
        if(row)counts[type==='spot'?'spots':'venues']++;else counts[type==='spot'?'invalidSpots':'unpublishedOrIncompleteVenues']++;
        if(apply){
          if(type==='spot'&&row&&links[i].data()?.serialized===JSON.stringify(row))counts.alreadyProjected++;
          else pending.push(doc.id);
        }
      }
      if(apply){
        if(type==='spot')for(let i=0;i<pending.length;i+=80)await projectSpots(db,pending.slice(i,i+80));
        else await parallel(pending,id=>project(db,type,id));
      }
      if(page.size<200)break;cursor=page.docs.at(-1).id;
    }
  }
  if(apply){
    const partitions=provinces.flatMap(city=>kinds.map(kind=>({city,kind})));
    await parallel(partitions,async({city,kind})=>{
      const ref=db.doc(`place_catalog/${partition(city,kind)}`);
      await db.runTransaction(async tx=>{const old=(await tx.get(ref)).data()||{};tx.set(ref,{schemaVersion:1,city,kind,count:old.count||0,ready:true,sourceStatus:old.sourceStatus||(kind==='gezi'?'ready':'pending'),migratedAt:FieldValue.serverTimestamp()},{merge:true});});
    },12);
  }
  console.log(JSON.stringify(counts));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
