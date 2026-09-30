'use strict';
const fs=require('node:fs');
const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
const project='projects/en-iyi-cekim-noktasi',base='https://firebaserules.googleapis.com/v1/';
const state=process.env.RUNNER_TEMP+'/e2ee-rules-base.json';
function block(s,marker){const start=s.indexOf(marker);if(start<0)throw Error('Missing rule '+marker);const open=s.indexOf('{',start+marker.length);let end=open+1,depth=1;for(;depth&&end<s.length;end++){if(s[end]==='{')depth++;if(s[end]==='}')depth--;}if(depth)throw Error('Unbalanced '+marker);return {start,open,end,text:s.slice(start,end)};}
function guard(s,kind,condition){const pattern=new RegExp('allow '+kind+': if ');if(!pattern.test(s))throw Error('Missing '+kind+' rule');return s.replace(pattern,'allow '+kind+': if '+condition+' && ');}
(async()=>{
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const read=async p=>(await client.request({url:base+p})).data;
 const targets=[['firestore.rules','cloud.firestore'],['storage.rules','firebase.storage/en-iyi-cekim-noktasi.firebasestorage.app']];
 const records=[];
 for(const [file,suffix] of targets){
  const release=project+'/releases/'+suffix,current=await read(release);
  if(process.argv.includes('--deploy')){
   const prior=JSON.parse(fs.readFileSync(state)).find(x=>x.file===file);
   if(current.rulesetName!==prior.rulesetName)throw Error('Live rules changed since tests: '+file);
   const content=fs.readFileSync(file,'utf8');
   const set=(await client.request({url:base+project+'/rulesets',method:'POST',data:{source:{files:[{name:file,content}]}}})).data;
   await client.request({url:base+release,method:'PATCH',data:{release:{name:release,rulesetName:set.name},updateMask:'rulesetName'}});
   if((await read(release)).rulesetName!==set.name)throw Error('Rules readback failed');
   console.log('E2EE_COMPAT_RULES_DEPLOYED '+file+' '+set.name);continue;
  }
  const live=await read(current.rulesetName);if(live.source.files.length!==1)throw Error('Unexpected rule sources');
  let content=live.source.files[0].content;
  const candidate=fs.readFileSync(file,'utf8');
  if(file==='storage.rules'){
   for(const scope of ['chat','event','route']){
    const marker='match /e2ee_'+scope+'/';
    if(content.includes(marker))throw Error('E2EE storage path already present; review before updating');
    const path=scope==='chat'?'match /e2ee_chat/{threadId}/{uid}/{messageId}/payload.bin':'match /e2ee_'+scope+'/{parentId}/{uid}/{messageId}/payload.bin';
    content=content.replace('match /b/{bucket}/o {','match /b/{bucket}/o {\n'+block(candidate,path).text);
   }
  }else{
   if(content.includes('match /e2ee_identities/'))throw Error('E2EE rules already present; review before updating');
   const root='match /databases/{database}/documents {';
   content=content.replace(root,root+'\n'+['e2ee_identities','e2ee_key_limits','e2ee_send_limits'].map(c=>block(candidate,'match /'+c+'/{uid}').text).join('\n'));
   for(const [collection,param,sub] of [['chat_threads','threadId','messages'],['social_events','eventId','chat'],['travel_plans','planId','messages']]){
    const parent=block(content,'match /'+collection+'/{'+param+'}');let p=parent.text;
    const nested=p.indexOf('match /',6);if(nested<0)throw Error('Missing subcollections');
    let head=p.slice(0,nested);
    head=guard(head,'create',"!request.resource.data.keys().hasAny(['e2eeVersion'])");
    let condition="request.resource.data.get('e2eeVersion',0) == resource.data.get('e2eeVersion',0)";
    if(collection==='chat_threads')condition+=" && (resource.data.get('e2eeVersion',0) != 1 || !request.resource.data.diff(resource.data).affectedKeys().hasAny(['lastMessage','lastMessageId','lastSenderId','lastMessageAt']))";
    head=guard(head,'update',condition);p=head+p.slice(nested);
    const msg=block(p,'match /'+sub+'/{messageId}');
    const conditionPath=`get(/databases/$(database)/documents/${collection}/$(${param})).data.get('e2eeVersion',0) != 1`;
    const replacement=guard(msg.text,'create',conditionPath);
    p=p.slice(0,msg.start)+replacement+p.slice(msg.end);
    content=content.slice(0,parent.start)+p+content.slice(parent.end);
   }
  }
  fs.writeFileSync(file,content);records.push({file,rulesetName:current.rulesetName});
 }
 if(!process.argv.includes('--deploy'))fs.writeFileSync(state,JSON.stringify(records));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
