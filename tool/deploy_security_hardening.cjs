const fs = require('node:fs');
const crypto = require('node:crypto');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
const {Storage} = require('../functions/node_modules/@google-cloud/storage');
const {_sealChatFile, _privatePath} = require('../functions/chat_media_security');
const PROJECT = 'projects/en-iyi-cekim-noktasi';
const BUCKET = 'en-iyi-cekim-noktasi.firebasestorage.app';
const BASE = 'https://firebaserules.googleapis.com/v1/';
const digest = s => crypto.createHash('sha256').update(s).digest('hex');
async function denied(url) {
  const r=await fetch(url,{headers:{Range:'bytes=0-0','Cache-Control':'no-cache'}});
  await r.body?.cancel();
  if(![401,403,404].includes(r.status)) throw Error('Anonymous access check failed: '+r.status);
}
async function main() {
 const client = await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const get = async name => (await client.request({url:BASE+name})).data;
 const mode=process.argv[2];
 const prepared='/tmp/security-live-baseline.json';
 const expected = mode==='prepare' ? {} : JSON.parse(fs.readFileSync(prepared,'utf8'));
 const patches=JSON.parse(fs.readFileSync('tool/security_rules_patch.json','utf8'));
 const policies = [['firestore','cloud.firestore'],['storage','firebase.storage/'+BUCKET]];
 // Verify both originals before changing either release. Re-runs accept the exact new policy.
 const pending=[];
 for (const [name,release] of policies) {
  const path=PROJECT+'/releases/'+release;
  const live=await get(path), rules=await get(live.rulesetName);
  if(rules.source.files.length!==1) throw Error('Unexpected live policy layout');
  let content=fs.readFileSync(name+'.rules','utf8');
  const original=rules.source.files[0].content;
  const hash=digest(original);
  if(mode==='prepare') {
   content=original;
   for(const [i,patch] of patches[name].entries()) {
    if(content.includes(patch.new))continue;
    if(content.split(patch.old).length!==2)throw Error(name+' live policy does not match reviewed patch '+i);
    content=content.replace(patch.old,patch.new);
   }
   expected[name]=hash;
   fs.writeFileSync(name+'.rules',content);
  }
  if(![expected[name]].flat().includes(hash) && hash!==digest(content)) throw Error(name+' live rules changed; refusing overwrite');
  pending.push({name,path,live,content,changed:hash!==digest(content)});
 }
 if(mode==='prepare') {fs.writeFileSync(prepared,JSON.stringify(expected));console.log('LIVE_RULE_PATCH_PREPARED');return;}
 if(mode==='check') {console.log('LIVE_RULE_BASE_VERIFIED');return;}
 if(process.argv[2]!=='deploy') throw Error('Expected check or deploy');
 for(const p of pending) {
  if(p.changed) {
   if((await get(p.path)).rulesetName!==p.live.rulesetName)throw Error('Concurrent rules change');
   const rules=(await client.request({url:BASE+PROJECT+'/rulesets',method:'POST',data:{source:{files:[{name:p.name+'.rules',content:p.content}]}}})).data;
   await client.request({url:BASE+p.path,method:'PATCH',data:{release:{name:p.path,rulesetName:rules.name},updateMask:'rulesetName'}});
   if((await get(p.path)).rulesetName!==rules.name)throw Error('Release verification failed');
  }
  console.log('SECURITY_RULES_ACTIVE '+p.name);
 }
 const bucket=new Storage().bucket(BUCKET);let objects=0,tokens=0;
 for(const prefix of ['route_albums/','route_chat/','event_chat/','users/']) {
  let query={prefix,maxResults:100,autoPaginate:false};
  while(query) {
   const [files,next]=await bucket.getFiles(query);
   for(const f of files) {
    if(!_privatePath(f.name))continue;
    const [before]=await f.getMetadata();
    const old=(before.metadata?.firebaseStorageDownloadTokens||'').split(',').filter(Boolean);
    await _sealChatFile(f);
    const url='https://firebasestorage.googleapis.com/v0/b/'+BUCKET+'/o/'+encodeURIComponent(f.name)+'?alt=media';
    await denied(url);
    for(const token of old)await denied(url+'&token='+encodeURIComponent(token));
    objects++;tokens+=old.length;
   }
   query=next;
  }
 }
 console.log('PRIVATE_MEDIA_SEALED '+JSON.stringify({objects,revokedTokens:tokens,anonymousAccess:'denied'}));
}
main().catch(e=>{console.error('Security deployment stopped',e.response?.status||e.code||e.message);process.exitCode=1;});
