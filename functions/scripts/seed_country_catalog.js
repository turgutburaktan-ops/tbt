const fs=require('node:fs'),readline=require('node:readline');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {decode}=require('../catalog/importer');
const {partition,provinces}=require('../catalog/schema');
const {seedRows}=require('../catalog/seed');
initializeApp();const db=getFirestore();
(async()=>{
  const groups=new Map();
  for await(const line of readline.createInterface({input:fs.createReadStream(process.argv[2]),crlfDelay:Infinity})){
    const d=JSON.parse(line),key=partition(d.city,d.kind);if(!key)throw Error('Invalid partition in extract');
    if(!groups.has(key))groups.set(key,{city:d.city,kind:d.kind,elements:[{type:'area'}]});
    groups.get(key).elements.push(d.element);
  }
  if(new Set([...groups.values()].map(g=>g.city)).size!==81)throw Error('Extract does not cover 81 provinces');
  const queue=[...groups.values()].sort((a,b)=>(a.city==='Elazığ'?-1:b.city==='Elazığ'?1:0));
  const result=[];
  async function worker(){while(queue.length){const g=queue.shift();
    const rows=decode(g,g.city,g.kind);
    for(let i=0;i<rows.length;i+=80)await seedRows(db,rows.slice(i,i+80));
    const ref=db.doc(`place_catalog/${partition(g.city,g.kind)}`);
    await ref.set({ready:true,sourceStatus:'ready',lastSeedCount:rows.length,lastSeedAt:FieldValue.serverTimestamp(),sourceError:FieldValue.delete()},{merge:true});
    const item={city:g.city,kind:g.kind,sourceRows:rows.length,count:(await ref.get()).data().count};result.push(item);console.log(JSON.stringify(item));
  }}
  await Promise.all(Array.from({length:4},worker));
  // All 81 provinces must retain the same three business partitions even where
  // the source has no named entries; no existing record is removed.
  for(const city of provinces)for(const kind of ['cafe','dining','hotel']){
    const ref=db.doc(`place_catalog/${partition(city,kind)}`);
    if(!groups.has(partition(city,kind)))await ref.set({ready:true,sourceStatus:'ready',lastSeedCount:0,lastSeedAt:FieldValue.serverTimestamp()},{merge:true});
  }
  fs.writeFileSync('build/catalog-country/import-report.json',JSON.stringify(result,null,2));
  console.log('Country catalog seed complete',result.reduce((n,r)=>n+r.sourceRows,0));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
