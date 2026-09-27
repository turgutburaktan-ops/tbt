const fs=require('node:fs');
const {createHash}=require('node:crypto');
const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
const {patchContactRules}=require('./contact_privacy_rules.cjs');
const hash=s=>createHash('sha256').update(s).digest('hex');
(async()=>{
 if(process.env.CONTACT_FREE_CLIENT_RELEASED!=='true')throw Error('Store availability gate has not passed');
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const base='https://firebaserules.googleapis.com/v1/',project='projects/en-iyi-cekim-noktasi';
 const path=project+'/releases/cloud.firestore';
 const get=async name=>(await client.request({url:base+name})).data;
 const live=await get(path),rule=await get(live.rulesetName);
 if(rule.source.files.length!==1)throw Error('Unexpected policy structure');
 const source=rule.source.files[0].content,patched=patchContactRules(source);
 const baseline='/tmp/contact-rules-baseline.json';
 if(process.argv[2]==='prepare') {
  fs.writeFileSync('firestore.rules',patched);
  fs.writeFileSync(baseline,JSON.stringify({ruleset:live.rulesetName,original:hash(source),patched:hash(patched)}));
  console.log('CONTACT_POLICY_PREPARED');return;
 }
 if(process.argv[2]!=='deploy')throw Error('Expected prepare or deploy');
 const expected=JSON.parse(fs.readFileSync(baseline,'utf8'));
 if(live.rulesetName!==expected.ruleset||hash(source)!==expected.original||hash(patched)!==expected.patched||hash(fs.readFileSync('firestore.rules','utf8'))!==expected.patched)throw Error('Policy changed after validation');
 if(source!==patched) {
  const created=(await client.request({url:base+project+'/rulesets',method:'POST',data:{source:{files:[{name:'firestore.rules',content:patched}]}}})).data;
  if((await get(path)).rulesetName!==live.rulesetName)throw Error('Concurrent policy update');
  await client.request({url:base+path,method:'PATCH',data:{release:{name:path,rulesetName:created.name},updateMask:'rulesetName'}});
  if((await get(path)).rulesetName!==created.name)throw Error('Policy readback failed');
 }
 console.log('CONTACT_FIELD_WRITES_DENIED');
})().catch(e=>{console.error('Contact policy deployment failed',e.response?.status||e.code||e.message);process.exitCode=1;});
