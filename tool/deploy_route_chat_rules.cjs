const fs = require('node:fs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
(async () => {
 const client = await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const base = 'https://firebaserules.googleapis.com/v1/';
 const project = 'projects/en-iyi-cekim-noktasi';
 const release = project+'/releases/firebase.storage/en-iyi-cekim-noktasi.firebasestorage.app';
 const read = async name => (await client.request({url:base+name})).data;
 const current = await read(release);
 if (process.argv.includes('--deploy')) {
  const expected = JSON.parse(fs.readFileSync('/tmp/route-chat-base.json','utf8'));
  if(current.rulesetName !== expected.rulesetName) throw Error('Live Storage rules changed during testing; refusing to overwrite');
  const content = fs.readFileSync('storage.rules','utf8');
  const set = (await client.request({url:base+project+'/rulesets',method:'POST',data:{source:{files:[{name:'storage.rules',content}]}}})).data;
  await client.request({url:base+release,method:'PATCH',data:{release:{name:release,rulesetName:set.name},updateMask:'rulesetName'}});
  const verified = await read(release);
  if(verified.rulesetName !== set.name) throw Error('Release verification failed');
  console.log('Verified private route voice Storage rule deployed; existing rules preserved.');
 } else {
  const live = await read(current.rulesetName);
  if(live.source.files.length !== 1) throw Error('Multiple Storage source files require review');
  let content = live.source.files[0].content;
  const rule = fs.readFileSync('tool/route_chat_storage_rule.txt','utf8');
  if(content.includes('match /route_chat/')) {
   if(!content.includes(rule.trim())) throw Error('Existing route chat rules differ; refusing replacement');
  } else {
   const marker='match /b/{bucket}/o {';
   if(!content.includes(marker)) throw Error('Unknown Storage structure');
   content = content.replace(marker,marker+'\n'+rule);
  }
  fs.writeFileSync('storage.rules',content);
  fs.writeFileSync('/tmp/route-chat-base.json',JSON.stringify({rulesetName:current.rulesetName}));
  const firestore = await read((await read(project+'/releases/cloud.firestore')).rulesetName);
  fs.writeFileSync('firestore.rules',firestore.source.files[0].content);
  console.log('Prepared live policy plus private route voice path for emulator tests.');
 }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
