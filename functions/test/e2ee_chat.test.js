const {test}=require('node:test');
const assert=require('node:assert/strict');
const {_register:register,_claim:claim,_send:send,_validatePacket:validatePacket,_validateBundle:validateBundle}=require('../e2ee_chat');
const b64=n=>Buffer.alloc(n,7).toString('base64');
const bundle=()=>({version:1,registrationId:123,deviceId:1,identityKey:b64(33),signedPreKey:{id:1,publicKey:b64(33),signature:b64(64)},preKeys:[{id:1,publicKey:b64(33)},{id:2,publicKey:b64(33)}]});
const packet=(members=['bob'])=>({version:1,senderId:'alice',envelopes:Object.fromEntries(members.map(m=>[m,{type:3,body:b64(100)}]))});
function harness(extra={}){
 const records=new Map(Object.entries({'users/alice':{accountStatus:'active'},'users/bob':{accountStatus:'active'},'chat_threads/dm':{type:'direct',memberIds:['alice','bob']},'e2ee_identities/alice':bundle(),'e2ee_identities/bob':bundle(),...extra}));
 const reference=path=>({path,collection:name=>collection(`${path}/${name}`)});
 const collection=path=>({doc:id=>reference(`${path}/${id}`),limit:n=>({query:path,limit:n})});
 const snapshot=ref=>({exists:records.has(ref.path),ref,data:()=>records.get(ref.path)});
 const db={doc:reference,collection,runTransaction:async fn=>{
  const writes=[];
  const value=await fn({get:async ref=>ref.query?{docs:[...records.keys()].filter(p=>p.startsWith(ref.query+'/')&&p.split('/').length===ref.query.split('/').length+1).slice(0,ref.limit).map(p=>snapshot(reference(p)))}:snapshot(ref),create:(ref,v)=>writes.push(()=>{assert(!records.has(ref.path));records.set(ref.path,v);}),set:(ref,v)=>writes.push(()=>records.set(ref.path,v)),update:(ref,v)=>writes.push(()=>records.set(ref.path,{...records.get(ref.path),...v})),delete:ref=>writes.push(()=>records.delete(ref.path))});
  writes.forEach(f=>f());return value;
 }};
 return {db,records};
}
const request=data=>({auth:{uid:'alice'},data});
test('key and packet schemas reject secrets, plaintext, foreign recipients and malformed encodings',()=>{
 validateBundle(bundle());validatePacket(packet(),'alice',['alice','bob']);
 for(const value of [{...bundle(),privateKey:'never'},{...bundle(),preKeys:[{id:1,publicKey:b64(33)},{id:1,publicKey:b64(33)}]}])assert.throws(()=>validateBundle(value));
 for(const value of [{...packet(),text:'secret'},packet(['mallory']),{...packet(),senderId:'mallory'},{version:1,senderId:'alice',envelopes:{bob:{type:3,body:'invalid'}}}])assert.throws(()=>validatePacket(value,'alice',['alice','bob']));
});
test('identity registration is immutable and retry cannot republish consumed prekeys',async()=>{
 const h=harness();h.records.delete('e2ee_identities/alice');
 await register(request(bundle()),h.db);
 assert(h.records.has('e2ee_identities/alice/prekeys/1'));
 h.records.delete('e2ee_identities/alice/prekeys/1');
 await register(request(bundle()),h.db);
 assert(!h.records.has('e2ee_identities/alice/prekeys/1'));
 await assert.rejects(register(request({...bundle(),identityKey:Buffer.alloc(33,8).toString('base64')}),h.db));
});
test('prekeys are claimed once and only between current authorized members',async()=>{
 const h=harness({'e2ee_identities/bob/prekeys/1':{id:1,publicKey:b64(33)}});
 assert.equal((await claim(request({threadId:'dm',peerId:'bob',consumePreKey:false}),h.db)).preKey,null);
 assert(h.records.has('e2ee_identities/bob/prekeys/1'));
 assert.equal((await claim(request({threadId:'dm',peerId:'bob'}),h.db)).preKey.id,1);
 assert.equal((await claim(request({threadId:'dm',peerId:'bob'}),h.db)).preKey,null);
 await assert.rejects(claim(request({threadId:'dm',peerId:'outsider'}),h.db));
 h.records.set('users/bob/blocked/alice',{});
 await assert.rejects(claim(request({threadId:'dm',peerId:'bob'}),h.db));
});
test('send stores opaque envelopes and generic preview, with retry protection',async()=>{
 const h=harness(),d={threadId:'dm',messageId:'one',packet:packet()};
 await send(request(d),h.db);
 const m=h.records.get('chat_threads/dm/messages/one'),t=h.records.get('chat_threads/dm');
 assert.equal(m.type,'e2ee');assert.equal(m.text,'Şifreli mesaj');assert.equal(t.lastMessage,'Şifreli mesaj');assert.equal(t.e2eeVersion,1);
 assert.equal((await send(request(d),h.db)).alreadySent,true);
 await assert.rejects(send(request({...d,text:'leak'}),h.db));
 const changed=packet();changed.envelopes.bob.body=b64(101);
 await assert.rejects(send(request({...d,packet:changed}),h.db));
});
test('missing identities, blocked or frozen accounts and changed membership reject writes',async()=>{
 for(const mutation of [h=>h.records.delete('e2ee_identities/bob'),h=>h.records.set('chat_threads/dm',{type:'direct',memberIds:['alice','bob'],requestStatus:'rejected'}),h=>h.records.set('users/alice',{accountStatus:'frozen'}),h=>h.records.set('users/bob/blocked/alice',{}),h=>h.records.set('chat_threads/dm',{type:'group',memberIds:['alice','bob','carol']})]){
  const h=harness();mutation(h);
  await assert.rejects(send(request({threadId:'dm',messageId:'one',packet:packet()}),h.db));
  assert(!h.records.has('chat_threads/dm/messages/one'));
 }
});
test('route and event messages use their own membership and collections',async()=>{
 for(const [scope,parent,sub] of [['route','travel_plans','messages'],['event','social_events','chat']]){
  const h=harness({[`${parent}/plan`]:scope==='event'?{hostId:'alice',participantIds:['bob'],status:'open'}:{ownerId:'alice',memberIds:['alice','bob']}});
  await send(request({scope,threadId:'plan',messageId:'one',packet:packet()}),h.db);
  assert.equal(h.records.get(`${parent}/plan/${sub}/one`).type,'e2ee');
  assert.equal(h.records.get(`${parent}/plan`).e2eeVersion,1);
  assert(!h.records.has('chat_threads/plan/messages/one'));
 }
 const h=harness({'social_events/plan':{hostId:'alice',participantIds:['bob'],status:'cancelled'}});
 await assert.rejects(send(request({scope:'event',threadId:'plan',messageId:'one',packet:packet()}),h.db));
});
test('legacy reply and edit handlers reject encrypted threads without writing plaintext',async()=>{
 const h=harness({'chat_threads/dm':{type:'direct',memberIds:['alice','bob'],e2eeVersion:1},'users/alice/notifications/n':{sourceId:'dm',type:'message',actorId:'bob'}});
 const {_reply}=require('../notification_reply');
 await assert.rejects(_reply(request({threadId:'dm',notificationId:'n',text:'secret'}),h.db));
 assert(![...h.records.keys()].some(k=>k.startsWith('chat_threads/dm/messages/')));
});
test('encrypted edits require the author, current revision and time window; polls expose only option count',async()=>{
 const h=harness();
 await send(request({threadId:'dm',messageId:'one',packet:packet(),kind:'text'}),h.db);
 const m=h.records.get('chat_threads/dm/messages/one');m.createdAt={toMillis:()=>Date.now()};
 const changed=packet();changed.envelopes.bob.body=b64(101);
 await send(request({threadId:'dm',messageId:'one',packet:changed,kind:'text',revision:1}),h.db);
 assert.equal(h.records.get('chat_threads/dm/messages/one').revision,1);
 const stale=packet();stale.envelopes.bob.body=b64(102);
 await assert.rejects(send(request({threadId:'dm',messageId:'one',packet:stale,kind:'text',revision:1}),h.db));
 await send(request({threadId:'dm',messageId:'poll',packet:packet(),kind:'poll',pollOptionCount:3}),h.db);
 assert.equal(h.records.get('chat_threads/dm/messages/poll').options,undefined);
 assert.equal(h.records.get('chat_threads/dm/messages/poll').pollOptionCount,3);
});
