// Preserve every deployed rule. Add only the public catalog read scope.
const fs=require('node:fs');
const {applicationDefault}=require('firebase-admin/app');
const block=`
    // BEGIN TBT SHARED CATALOG
    match /place_catalog/{partition} {
      allow read: if true;
      allow write: if false;
      match /items/{id} { allow read: if true; allow write: if false; }
    }
    match /catalog_external_venues/{id} { allow read, write: if false; }
    match /catalog_links/{id} { allow read, write: if false; }
    match /catalog_jobs/{id} { allow read, write: if false; }
    match /catalog_exclusions/{id} { allow read, write: if false; }
    // END TBT SHARED CATALOG
`;
(async()=>{
  const credential=applicationDefault(),project='en-iyi-cekim-noktasi';
  async function api(path,method='GET',body){
    const token=(await credential.getAccessToken()).access_token;
    const r=await fetch(`https://firebaserules.googleapis.com/v1/${path}`,{method,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
    if(!r.ok)throw Error(`Rules API ${method}: ${r.status} ${(await r.text()).slice(0,500)}`);
    return r.json();
  }
  const releasePath=`projects/${project}/releases/cloud.firestore`;
  const release=await api(releasePath),ruleset=await api(release.rulesetName);
  const files=ruleset.source.files.map(f=>({...f}));
  if(files.length!==1)throw Error('Expected one deployed rules file; refusing to replace multiple files');
  fs.mkdirSync('build/catalog-review',{recursive:true});
  fs.writeFileSync('build/catalog-review/previous.rules',files[0].content);
  if(files[0].content.includes('// BEGIN TBT SHARED CATALOG')){
    if(!files[0].content.includes(block.trim()))throw Error('Existing catalog rules differ; review required');
    console.log('Catalog rules already present');return;
  }
  if(files[0].content.includes('match /place_catalog/'))throw Error('Existing unrecognized catalog rules; refusing duplicate rules');
  const marker='match /databases/{database}/documents {';
  if(files[0].content.split(marker).length!==2)throw Error('Cannot locate unique database scope');
  files[0].content=files[0].content.replace(marker,marker+block);
  fs.writeFileSync('build/catalog-review/proposed.rules',files[0].content);
  if(!process.argv.includes('--apply')){console.log('Prepared catalog-only addition to live rules');return;}
  const created=await api(`projects/${project}/rulesets`,'POST',{source:{files}});
  if((await api(releasePath)).rulesetName!==release.rulesetName)throw Error('Rules changed concurrently; release not updated');
  await api(releasePath,'PATCH',{release:{name:releasePath,rulesetName:created.name},updateMask:'rulesetName'});
  const verified=await api(releasePath);
  if(verified.rulesetName!==created.name)throw Error('Rule release verification failed');
  console.log('Catalog-only rules addition deployed and verified');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
