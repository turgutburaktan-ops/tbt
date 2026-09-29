const fs = require('node:fs');
const crypto = require('node:crypto');
const {applyStrictPatches} = require('./strict_rule_patches.cjs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
const {Storage} = require('../functions/node_modules/@google-cloud/storage');
const {revokePrivateMedia} = require('./revoke_private_media.cjs');
const PROJECT = 'projects/en-iyi-cekim-noktasi';
const BUCKET = 'en-iyi-cekim-noktasi.firebasestorage.app';
const BASE = 'https://firebaserules.googleapis.com/v1/';
const digest = s => crypto.createHash('sha256').update(s).digest('hex');
function patchStorage(source) {
 const marker='match /users/{uid}/{category}/{allPaths=**} {';
 const start=source.indexOf(marker);
 if(start<0||source.indexOf(marker,start+1)>=0)throw Error('Unexpected user-media rule structure');
 let end=start+marker.length,depth=1;
 while(depth&&end<source.length){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}
 let block=source.slice(start,end);
 const prior="category != 'chat'",next="!(category in ['chat', 'business_claims'])";
 if(!block.includes(next)) {
  if(block.split(prior).length!==4||!block.includes('isOwner(uid)')||!block.includes('safeMediaWrite()'))throw Error('Unexpected existing user-media access');
  block=block.replaceAll(prior,next);
 }
 source=source.slice(0,start)+block+source.slice(end);
 const evidence=`
    match /users/{uid}/business_claims/{claimId}/{fileName} {
      allow get: if isOwner(uid) || (signedIn() && request.auth.token.admin == true &&
        request.auth.token.email_verified == true && request.auth.token.email == 'turgutburaktan@gmail.com');
      allow list, write: if false;
    }
`;
 if(!source.includes('match /users/{uid}/business_claims/'))source=source.replace(marker,evidence+'    '+marker);
 else if(!source.includes(evidence.trim()))throw Error('Unexpected existing evidence policy');
 return source;
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
   if(name==='storage') content=patchStorage(content);
   content=applyStrictPatches(content,name==='storage'?(patches.e2eeStorage||[]):patches[name]);
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
 const result=await revokePrivateMedia(new Storage().bucket(BUCKET));
 console.log('PRIVATE_MEDIA_SEALED '+JSON.stringify(result));
}
main().catch(e=>{console.error('Security deployment stopped',e.response?.status||e.code||e.message);process.exitCode=1;});
