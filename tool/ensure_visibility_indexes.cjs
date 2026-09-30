// Append-only rollout. No existing index is deleted or weakened.
const fromFunctions=require('node:module').createRequire(require.resolve('../functions/package.json'));
const {applicationDefault}=fromFunctions('firebase-admin/app');
const credential=applicationDefault();
const desired=require('../firestore.indexes.json').indexes.filter(i=>i.fields.some(f=>f.fieldPath==='accountFrozen'));
const signature=i=>JSON.stringify({queryScope:i.queryScope,fields:i.fields.filter(f=>f.fieldPath!=='__name__').map(f=>({fieldPath:f.fieldPath,...(f.order?{order:f.order}:{arrayConfig:f.arrayConfig})}))});
const groups=[...new Set(desired.map(i=>i.collectionGroup))];
const parent=c=>`projects/en-iyi-cekim-noktasi/databases/(default)/collectionGroups/${c}/indexes`;
async function api(path,method='GET',body){
 const token=await credential.getAccessToken();
 const r=await fetch('https://firestore.googleapis.com/v1/'+path,{method,headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(60000)});
 const d=await r.json();if(!r.ok)throw Error(`Visibility index HTTP ${r.status}: ${d.error?.message||'failed'}`);return d;
}
async function list(c){const all=[];let page;do{const r=await api(parent(c)+(page?'?pageToken='+encodeURIComponent(page):''));all.push(...r.indexes||[]);page=r.nextPageToken;}while(page);return all;}
(async()=>{
 for(const c of groups){const have=new Set((await list(c)).map(signature));for(const i of desired.filter(i=>i.collectionGroup===c)){if(!have.has(signature(i))){await api(parent(c),'POST',{queryScope:i.queryScope,fields:i.fields});have.add(signature(i));}}}
 const deadline=Date.now()+20*60000;
 while(Date.now()<deadline){let waiting=0;for(const c of groups){const all=await list(c);for(const i of desired.filter(i=>i.collectionGroup===c)){const match=all.find(x=>signature(x)===signature(i));if(match?.state==='NEEDS_REPAIR')throw Error('Visibility index needs repair');if(match?.state!=='READY')waiting++;}}
  console.log('VISIBILITY_INDEXES '+JSON.stringify({total:desired.length,waiting}));if(!waiting)return;
  await new Promise(r=>setTimeout(r,10000));
 }
 throw Error('Visibility indexes still building; do not release yet');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
