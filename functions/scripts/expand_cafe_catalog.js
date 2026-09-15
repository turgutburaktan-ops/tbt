const fs=require('node:fs');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {seedRows}=require('../catalog/seed');
const {indexRows,validate}=require('../catalog/cafe_expansion');
const {partition}=require('../catalog/schema');
initializeApp();const db=getFirestore();
async function main(){
  const rows=fs.readFileSync(process.argv[2],'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
  if(!rows.length || rows.some(r=>!validate(r)))throw Error('Invalid cafe manifest');
  const apply=process.argv.includes('--apply');
  // Include unpublished external/owner rows, so removed businesses are not
  // resurrected under a new provider ID. Never overwrite their identities.
  const [external,business]=await Promise.all([
    db.collection('catalog_external_venues').get(),db.collection('business_venues').get()]);
  const existing=[...external.docs,...business.docs].map(d=>d.data());
  const index=indexRows(existing);
  const selected=[],report={apply,input:rows.length,duplicates:0,added:0,byCity:{}};
  rows.sort((a,b)=>(a.city==='Elazığ'?-1:b.city==='Elazığ'?1:0)||a.venueId.localeCompare(b.venueId));
  for(const r of rows){if(index.has(r)){report.duplicates++;continue;}index.add(r);selected.push(r);}
  if(!apply){report.proposed=selected.length;for(const r of selected)report.byCity[r.city]=(report.byCity[r.city]||0)+1;}
  else {
    const cities=[...new Set(selected.map(r=>r.city))];
    async function worker(){while(cities.length){const city=cities.shift();
      const batch=selected.filter(r=>r.city===city),ref=db.doc(`place_catalog/${partition(city,'cafe')}`);
      const before=(await ref.collection('items').count().get()).data().count;
      for(let i=0;i<batch.length;i+=60)await seedRows(db,batch.slice(i,i+60));
      const after=(await ref.collection('items').count().get()).data().count;
      const meta=(await ref.get()).data();
      if(after<before || meta.count!==after)throw Error(`Catalog count mismatch in ${city}`);
      await ref.set({ready:true,lastExpansionSource:'overture',lastExpansionAt:FieldValue.serverTimestamp()},{merge:true});
      report.byCity[city]={before,after,added:after-before};report.added+=after-before;
      console.log(JSON.stringify({city,...report.byCity[city]}));
    }}
    // Each worker owns a different province partition; seedRows transactions
    // remain bounded and idempotent, and no province count is shared by workers.
    await Promise.all(Array.from({length:4},worker));
  }
  fs.mkdirSync('build/cafe-expansion',{recursive:true});
  fs.writeFileSync(`build/cafe-expansion/${apply?'applied':'preview'}.json`,JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
