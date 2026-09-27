// Only creates the one event discovery index; never deletes or modifies other indexes.
const fromFunctions = require('node:module').createRequire(require.resolve('../functions/package.json'));
const {applicationDefault, initializeApp} = fromFunctions('firebase-admin/app');
const {getFirestore} = fromFunctions('firebase-admin/firestore');
const credential=applicationDefault();
initializeApp({credential,projectId:'en-iyi-cekim-noktasi'});
const root='https://firestore.googleapis.com/v1/';
const parent='projects/en-iyi-cekim-noktasi/databases/(default)/collectionGroups/social_events/indexes';
const desired={queryScope:'COLLECTION',fields:[{fieldPath:'visibility',order:'ASCENDING'},{fieldPath:'startsAt',order:'ASCENDING'}]};
async function api(path,method='GET',body){
  const token=await credential.getAccessToken();
  const response=await fetch(root+path,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
  const data=await response.json();
  if(!response.ok)throw new Error(`Firestore index ${response.status}: ${data.error?.message||response.statusText}`);
  return data;
}
async function find(){
  let page;
  do {
    const data=await api(parent+(page?'?pageToken='+encodeURIComponent(page):''));
    const match=(data.indexes||[]).find(index=>index.queryScope===desired.queryScope&&index.fields.filter(x=>x.fieldPath!=='__name__').length===desired.fields.length&&desired.fields.every((field,i)=>index.fields[i]?.fieldPath===field.fieldPath&&index.fields[i]?.order===field.order));
    if(match)return match;
    page=data.nextPageToken;
  }while(page);
}
(async()=>{
  let index=await find();
  if(!index){await api(parent,'POST',desired);console.log('Event index creation requested.');}
  const deadline=Date.now()+10*60*1000;
  while(Date.now()<deadline){
    index=await find();
    if(index?.state==='READY'){
      // Verifies query planning without loading any customer's personal data.
      try { await getFirestore().collection('social_events').where('visibility','==','index-probe-no-events').where('startsAt','>=',new Date()).orderBy('startsAt').limit(1).select().get(); } catch(e) { if(e.code===9){await new Promise(r=>setTimeout(r,10000));continue;} throw e; }
      console.log('Event index READY; event discovery query verified.');return;
    }
    if(index?.state==='NEEDS_REPAIR')throw new Error('Event index needs repair.');
    console.log('Event index state: '+(index?.state||'CREATING'));
    await new Promise(resolve=>setTimeout(resolve,10000));
  }
  throw new Error('Event index is still building; check status before retrying.');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
