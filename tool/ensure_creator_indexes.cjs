// Add only the Creator/share indexes from the checked-in configuration. Never delete existing indexes.
const fromFunctions=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {applicationDefault}=fromFunctions('firebase-admin/app');
const credential=applicationDefault();
const desired=require('../firestore.indexes.json').indexes.filter(i=>i.collectionGroup==='post_reposts'||(i.collectionGroup==='stories'&&i.fields.some(f=>f.fieldPath==='sharedPostId')));
async function api(path,method='GET',body){
 const token=await credential.getAccessToken();
 const response=await fetch('https://firestore.googleapis.com/v1/'+path,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 const value=await response.json();if(!response.ok)throw Error(`Creator index request failed (${response.status})`);return value;
}
async function ensure(spec){
 const parent=`projects/en-iyi-cekim-noktasi/databases/(default)/collectionGroups/${spec.collectionGroup}/indexes`;
 async function find(){let page;do{const result=await api(parent+(page?'?pageToken='+encodeURIComponent(page):''));const found=(result.indexes||[]).find(i=>i.queryScope===spec.queryScope&&i.fields.filter(f=>f.fieldPath!=='__name__').length===spec.fields.length&&spec.fields.every((f,n)=>i.fields[n]?.fieldPath===f.fieldPath&&i.fields[n]?.order===f.order));if(found)return found;page=result.nextPageToken;}while(page);}
 if(!await find())await api(parent,'POST',{queryScope:spec.queryScope,fields:spec.fields});
 const deadline=Date.now()+10*60*1000;
 while(Date.now()<deadline){const index=await find();if(index?.state==='READY'){console.log(`${spec.collectionGroup} Creator index READY`);return;}if(index?.state==='NEEDS_REPAIR')throw Error(`${spec.collectionGroup} index needs repair`);await new Promise(r=>setTimeout(r,10000));}
 throw Error(`${spec.collectionGroup} index still building; retry before release`);
}
Promise.all(desired.map(ensure)).catch(e=>{console.error(e.message);process.exitCode=1;});
