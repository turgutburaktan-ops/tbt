const {test}=require('node:test');
const assert=require('node:assert/strict');
const {_directMessage,_contentEngagement,_communityEvent}=require('../functions/trusted_notifications');
function fixture(type='direct',members=['sender','peer'],blocked=false){
 const notifications=new Map();const db={doc:path=>({
  get:async()=>({exists: path==='users/sender'||(blocked&&path==='users/peer/blocked/sender'),data:()=>path==='chat_threads/t'?{type,memberIds:members}:path==='users/sender'?{displayName:'Name'}:undefined}),
  create:async d=>{if(notifications.has(path)){const e=Error();e.code=6;throw e;}notifications.set(path,d);},
 })};return {db,notifications};
}
const event=(extra={})=>({id:'same-event',params:{threadId:'t',messageId:'m'},data:{data:()=>({type:'text',senderId:'sender',text:'Actual message',...extra})}});
test('Real direct message generates one server-derived notification across retries',async()=>{
 const f=fixture();await _directMessage(event(),f.db);await _directMessage(event(),f.db);
 assert.equal(f.notifications.size,1);const [n]=f.notifications.values();assert.equal(n.body,'Actual message');assert.equal(n.actorId,'sender');assert.equal(n.sourceId,'t');
});
test('Nonmember, blocked and unsupported thread cannot generate notification',async()=>{
 for(const f of [fixture('direct',['a','peer']),fixture('direct',['sender','peer'],true),fixture('missing')]){await _directMessage(event(),f.db);assert.equal(f.notifications.size,0);}
});
test('Existing private-photo and reply notification paths are not duplicated',async()=>{
 for(const extra of [{type:'private_photo'},{source:'notification_reply'},{deleted:true}]){const f=fixture();await _directMessage(event(extra),f.db);assert.equal(f.notifications.size,0);}
});

test('Event engagement targets the stored host, ignores forged actor and is retry-safe',async()=>{
 const f=fixture();const base=f.db.doc;
 f.db.doc=path=>path==='social_events/event'?{get:async()=>({data:()=>({hostId:'peer'})})}:base(path);
 const e={id:'engagement',params:{contentId:'event',actor:'sender'},data:{data:()=>({userId:'sender',ownerId:'forged-owner'})}};
 await _contentEngagement(e,'social_events','like',f.db);
 await _contentEngagement(e,'social_events','like',f.db);
 assert.equal(f.notifications.size,1);
 assert.ok([...f.notifications.keys()][0].startsWith('users/peer/notifications/'));
 assert.equal([...f.notifications.values()][0].type,'social_event_like');
 e.id='forged';e.params.actor='different';
 await _contentEngagement(e,'social_events','like',f.db);
 assert.equal(f.notifications.size,1);
});
test('Private events and events from non-admin community members never fan out to followers',async()=>{
 for(const visibility of ['private','public']) {
  const f=fixture();const base=f.db.doc;
  f.db.doc=path=>path==='communities/c'?{get:async()=>({data:()=>({ownerId:'other',adminIds:[]})})}:base(path);
  f.db.collection=()=>{throw Error('Private or unauthorized event reached followers');};
  await _communityEvent({id:'e',params:{eventId:'e'},data:{data:()=>({visibility,status:'open',communityId:'c',hostId:'sender'})}},f.db);
  assert.equal(f.notifications.size,0);
 }
});
