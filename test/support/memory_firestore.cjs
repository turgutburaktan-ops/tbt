// Lightweight test double for handler validation. Emulator tests remain the
// integration gate for Firestore transaction retries and security rules.
function memoryFirestore() {
 const records=new Map();let queue=Promise.resolve();
 const snapshot=ref=>({id:ref.id,exists:records.has(ref.path),data:()=>records.get(ref.path)});
 const doc=path=>({path,id:path.split('/').at(-1),
  get:async()=>snapshot(doc(path)),set:async data=>records.set(path,{...data})});
 function query(path,filters=[]) {return {
  where:(field,op,value)=>query(path,[...filters,[field,op,value]]),
  get:async()=>{const docs=[...records].filter(([key,data])=>key.startsWith(path+'/')&&key.split('/').length===path.split('/').length+1&&filters.every(([f,op,v])=>{if(op!=='==')throw Error('unsupported test query');return data[f]===v;})).map(([key])=>snapshot(doc(key)));return {docs,size:docs.length};},
  doc:id=>doc(path+'/'+(id||`auto_${records.size}`))};}
 const db={doc,collection:query,
  recursiveDelete:async ref=>{const rows=await ref.get();for(const d of rows.docs)records.delete(ref.doc(d.id).path);},
  batch:()=>{const writes=[];return {set:(ref,data)=>writes.push([ref,data]),commit:async()=>{for(const [r,d]of writes)records.set(r.path,{...d});}};},
  runTransaction:fn=>{const next=queue.then(async()=>{const writes=[];const tx={get:r=>r.get(),set:(r,d)=>writes.push(()=>records.set(r.path,{...d})),update:(r,d)=>writes.push(()=>records.set(r.path,{...records.get(r.path),...d}))};const result=await fn(tx);writes.forEach(w=>w());return result;});queue=next.catch(()=>{});return next;}
 };return db;
}
module.exports={memoryFirestore};
