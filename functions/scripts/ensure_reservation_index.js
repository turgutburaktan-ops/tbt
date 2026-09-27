// Only creates the one reservation index; never deletes or modifies other indexes.
const {applicationDefault, initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const credential=applicationDefault();
initializeApp({credential,projectId:'en-iyi-cekim-noktasi'});
const root='https://firestore.googleapis.com/v1/';
const parent='projects/en-iyi-cekim-noktasi/databases/(default)/collectionGroups/reservations/indexes';
const desired={queryScope:'COLLECTION_GROUP',fields:[{fieldPath:'userUid',order:'ASCENDING'},{fieldPath:'at',order:'DESCENDING'}]};
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
  if(!index){await api(parent,'POST',desired);console.log('Reservation index creation requested.');}
  const deadline=Date.now()+10*60*1000;
  while(Date.now()<deadline){
    index=await find();
    if(index?.state==='READY'){
      // Verifies query planning without loading any customer's personal data.
      await getFirestore().collectionGroup('reservations').where('userUid','==','reservation-index-probe-no-user').orderBy('at','desc').limit(1).select().get();
      console.log('Reservation index READY; personal reservation query verified.');return;
    }
    if(index?.state==='NEEDS_REPAIR')throw new Error('Reservation index needs repair.');
    console.log('Reservation index state: '+(index?.state||'CREATING'));
    await new Promise(resolve=>setTimeout(resolve,10000));
  }
  throw new Error('Reservation index is still building; check status before retrying.');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
