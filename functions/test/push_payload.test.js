const test=require('node:test'),assert=require('node:assert/strict');
const {notificationPayload:payload}=require('../push_payload');
const target={userId:'u',notificationId:'n'};
test('chat reply capability preserves old clients while enabling Android actions and iOS category',()=>{
 const data={type:'message',sourceId:'thread',actorId:'sender',title:'Ayşe',body:'Merhaba'};
 const legacy=payload(data,target),modern=payload(data,{...target,modernAndroid:true});
 assert.equal(legacy.notification.title,'Ayşe');assert.equal(modern.notification,undefined);
 assert.equal(modern.data.recipientId,'u');assert.equal(modern.data.notificationId,'n');assert.equal(modern.data.sourceId,'thread');
 assert.equal(legacy.apns.payload.aps.category,'TBT_CHAT');assert.equal(legacy.apns.payload.aps.threadId,'thread');
});
test('event routing and announcement photo remain in standard pushes',()=>{
 assert.equal(payload({type:'event_join',sourceId:'event'},target).data.eventId,'event');
 assert.equal(payload({type:'community',communityId:'club'},target).data.communityId,'club');
 const result=payload({type:'tbt_broadcast',imageUrl:'https://example.com/image.jpg'},{...target,modernAndroid:true});
 assert.equal(result.notification.imageUrl,'https://example.com/image.jpg');assert.equal(result.apns.payload.aps.category,undefined);
});
