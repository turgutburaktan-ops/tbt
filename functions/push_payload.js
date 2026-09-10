const EVENT_TYPES = new Set(['event_join','social_event_join','event_cancelled','social_event_cancelled','event_updated','event_time_changed','event_reminder','community_event','event_memory','campus_digest']);
// Android clients advertise action support before receiving data-only chat pushes.
function notificationPayload(data,{userId,notificationId,modernAndroid=false}){
  const type=String(data.type||'general'),sourceId=String(data.sourceId||''),actorId=String(data.actorId||''),isChat=['message','group_message'].includes(type);
  const title=String(data.title||'TBT'),body=String(data.body||'Yeni bir bildirimin var.');
  const imageUrl=data.type==='tbt_broadcast'?String(data.imageUrl||''):'';
  return {
    ...(!(modernAndroid&&isChat)?{notification:{title,body,...(imageUrl?{imageUrl}:{})}}:{}),
    data:{type,sourceId,actorId,title,body,recipientId:userId,notificationId,imageUrl,eventId:String(data.eventId||(EVENT_TYPES.has(type)?sourceId:'')),communityId:String(data.communityId||(type==='community'?sourceId:''))},
    android:{priority:'high',...(modernAndroid&&isChat?{}:{notification:{sound:'default'}})},
    apns:{payload:{aps:{sound:'default',badge:1,...(isChat?{category:'TBT_CHAT',threadId:sourceId}:{})}}},
  };
}
exports.notificationPayload=notificationPayload;
