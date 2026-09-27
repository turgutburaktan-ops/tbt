const fs=require('node:fs');
const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
const {Storage}=require('../functions/node_modules/@google-cloud/storage');
const {_sealChatFile}=require('../functions/chat_media_security');
const BUCKET='en-iyi-cekim-noktasi.firebasestorage.app';
const RULE_MARK='// TBT authenticated chat media v1.';
function patchRules(source) {
  if (source.includes(RULE_MARK)) {
    if (!source.includes(fs.readFileSync('tool/chat_media_storage_rules.txt','utf8').trim()))
      throw Error('Different private chat rules already exist; refusing overwrite');
    return source;
  }
  const marker='match /users/{uid}/{allPaths=**} {';
  const start=source.indexOf(marker);
  if(start<0 || source.indexOf(marker,start+1)>=0) throw Error('Unknown user rules structure');
  let end=start+marker.length,depth=1;
  while(depth && end<source.length) {if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}
  let block=source.slice(start,end);
  if(!block.includes('allow read: if true;') || !block.includes('if isOwner(uid)'))
    throw Error('Unexpected user Storage policy; refusing replacement');
  block=block.replace(marker,'match /users/{uid}/{category}/{allPaths=**} {')
    .replace('allow read: if true;', "allow read: if category != 'chat';")
    .replaceAll('if isOwner(uid)',"if category != 'chat' && isOwner(uid)");
  return source.slice(0,start)+block+'\n'+fs.readFileSync('tool/chat_media_storage_rules.txt','utf8')+source.slice(end);
}
async function denied(url) {
  const response=await fetch(url,{headers:{Range:'bytes=0-0','Cache-Control':'no-cache'}});
  await response.body?.cancel();
  if(![401,403,404].includes(response.status)) throw Error('Anonymous media access did not fail closed: HTTP '+response.status);
}
async function main() {
  const mode=process.argv[2];
  const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const base='https://firebaserules.googleapis.com/v1/', project='projects/en-iyi-cekim-noktasi';
  const release=project+'/releases/firebase.storage/'+BUCKET;
  const get=async name=>(await client.request({url:base+name})).data;
  const current=await get(release);
  if(mode==='prepare') {
    const rules=await get(current.rulesetName);
    if(rules.source.files.length!==1)throw Error('Unexpected Storage rule layout');
    fs.writeFileSync('storage.rules',patchRules(rules.source.files[0].content));
    const fire=await get((await get(project+'/releases/cloud.firestore')).rulesetName);
    fs.writeFileSync('firestore.rules',fire.source.files[0].content);
    fs.writeFileSync('/tmp/chat-security-base.json',JSON.stringify({ruleset:current.rulesetName}));
    console.log('Prepared current live Storage rules with private chat exclusion; no remote changes.');
  } else if(mode==='deploy') {
    const prior=JSON.parse(fs.readFileSync('/tmp/chat-security-base.json','utf8'));
    if(prior.ruleset!==current.rulesetName)throw Error('Live policy changed during testing; refusing overwrite');
    const content=fs.readFileSync('storage.rules','utf8');
    const rules=(await client.request({url:base+project+'/rulesets',method:'POST',
      data:{source:{files:[{name:'storage.rules',content}]}}})).data;
    await client.request({url:base+release,method:'PATCH',
      data:{release:{name:release,rulesetName:rules.name},updateMask:'rulesetName'}});
    if((await get(release)).rulesetName!==rules.name)throw Error('Storage release readback mismatch');
    console.log('PRIVATE_CHAT_RULES_DEPLOYED');
  } else if(mode==='revoke') {
    const rule=await get(current.rulesetName);
    if(!rule.source.files[0].content.includes(RULE_MARK))throw Error('Private rules must be active first');
    const bucket=new Storage().bucket(BUCKET);
    let count=0, tokens=0;
    // Old uploads are blocked before inventory; no new legacy objects can race in.
    const [files]=await bucket.getFiles({prefix:'users/'});
    for(const file of files) {
      const match=/^users\/([^/]+)\/chat\/([^/]+)\/([^/]+)\.[^.]+$/.exec(file.name);
      if(!match) continue;
      const [before]=await file.getMetadata();
      const oldTokens=(before.metadata?.firebaseStorageDownloadTokens||'').split(',').filter(Boolean);
      await file.setMetadata({metadata:{...before.metadata,chatMessageId:match[3]}},
        {ifMetagenerationMatch:before.metageneration});
      await _sealChatFile(file);
      const api='https://firebasestorage.googleapis.com/v0/b/'+BUCKET+'/o/'+encodeURIComponent(file.name)+'?alt=media';
      await denied(api);
      for(const token of oldTokens) await denied(api+'&token='+encodeURIComponent(token));
      await denied('https://storage.googleapis.com/'+BUCKET+'/'+file.name.split('/').map(encodeURIComponent).join('/'));
      count++;tokens+=oldTokens.length;
    }
    console.log(JSON.stringify({stage:'LEGACY_CHAT_SECURED',files:count,revokedTokens:tokens,anonymousChecks:'denied'}));
  } else throw Error('Expected prepare, deploy or revoke');
}
exports.patchRules=patchRules;
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
