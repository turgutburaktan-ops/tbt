const fs = require('node:fs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
(async () => {
 const client = await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const base='https://firebaserules.googleapis.com/v1/',project='projects/en-iyi-cekim-noktasi';
 const targets=[['firestore.rules','cloud.firestore'],['storage.rules','firebase.storage/en-iyi-cekim-noktasi.firebasestorage.app']];
 const read=async name=>(await client.request({url:base+name})).data;
 const records=[];
 for(const [file,suffix] of targets) {
  const release=project+'/releases/'+suffix,current=await read(release);
  if(process.argv.includes('--deploy')) {
   const prior=JSON.parse(fs.readFileSync('/tmp/event-chat-rules-base.json','utf8')).find(x=>x.file===file);
   if(prior.rulesetName!==current.rulesetName)throw Error('Live '+file+' changed after tests; refusing overwrite');
   const content=fs.readFileSync(file,'utf8');
   const set=(await client.request({url:base+project+'/rulesets',method:'POST',data:{source:{files:[{name:file,content}]}}})).data;
   await client.request({url:base+release,method:'PATCH',data:{release:{name:release,rulesetName:set.name},updateMask:'rulesetName'}});
   if((await read(release)).rulesetName!==set.name)throw Error('Release verification failed');
   console.log('Verified '+file+' event chat change deployed, unrelated live rules preserved.');
  } else {
   const live=await read(current.rulesetName);
   if(live.source.files.length!==1)throw Error('Multiple rule sources require review');
   let content=live.source.files[0].content;
   if(file==='firestore.rules') {
    const marker='match /social_events/{eventId} {';
    const event=content.indexOf(marker);if(event<0)throw Error('Event rules not found');
    const start=content.indexOf('match /chat/{messageId} {',event);if(start<0)throw Error('Event chat rules not found');
    let at=content.indexOf('{',start+'match /chat/{messageId}'.length),depth=1,end=at+1;
    for(;end<content.length&&depth;end++){if(content[end]==='{')depth++;if(content[end]==='}')depth--;}
    if(depth)throw Error('Invalid chat rule structure');
    const old=content.slice(start,end);
    if(!old.includes('eventChatMember(eventId)')||!old.includes("'senderName'"))throw Error('Unexpected live event chat policy; refusing replacement');
    content=content.slice(0,start)+fs.readFileSync('tool/event_chat_firestore_rule.txt','utf8').trim()+content.slice(end);
   } else {
    const rule=fs.readFileSync('tool/event_chat_storage_rule.txt','utf8');
    if(content.includes('match /event_chat/')) {if(!content.includes(rule.trim()))throw Error('Existing event chat Storage policy differs');}
    else {const marker='match /b/{bucket}/o {';if(!content.includes(marker))throw Error('Unknown Storage structure');content=content.replace(marker,marker+'\n'+rule);}
   }
   fs.writeFileSync(file,content);records.push({file,rulesetName:current.rulesetName});
  }
 }
 if(!process.argv.includes('--deploy'))fs.writeFileSync('/tmp/event-chat-rules-base.json',JSON.stringify(records));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
