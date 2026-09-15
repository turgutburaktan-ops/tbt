const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {refreshPartition}=require('../catalog/importer');
initializeApp();const db=getFirestore();
(async()=>{
  const metas=await db.collection('place_catalog').get();
  if(metas.size!==324||metas.docs.some(d=>d.data().ready!==true))throw Error('Province partitions are not ready');
  const counts={};
  for(const d of metas.docs){const m=d.data();counts[m.kind]=(counts[m.kind]||0)+m.count;}
  console.log('Migrated catalog totals',JSON.stringify(counts));
  // Source availability is reported honestly; failed refresh cannot erase rows.
  if(process.argv.includes('--sample-import'))for(const kind of ['cafe','dining','hotel'])console.log('Elazığ source import',JSON.stringify(await refreshPartition(db,'Elazığ',kind)));
  const fresh=await db.collection('place_catalog').where('city','==','Elazığ').get();
  console.log('Elazığ catalog',JSON.stringify(fresh.docs.map(d=>({kind:d.data().kind,count:d.data().count,status:d.data().sourceStatus}))));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
