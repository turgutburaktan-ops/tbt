const {onDocumentCreated,onDocumentWritten}=require('firebase-functions/v2/firestore');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const key = value => typeof value==='string' && value.length>0 && value.length<200 && !value.includes('/');
async function deliver(db,{target,actor,type,source,title,body,eventId}) {
 if(!key(target)||!key(actor)||target===actor)return;
 const [a,b,profile]=await Promise.all([db.doc(`users/${target}/blocked/${actor}`).get(),db.doc(`users/${actor}/blocked/${target}`).get(),db.doc(`users/${actor}`).get()]);
 if(a.exists||b.exists||!profile.exists||profile.data().disabled||profile.data().banned||['deleting','frozen'].includes(profile.data().accountStatus))return;
 const name=String(profile.data().displayName||profile.data().username||'Bir kullanıcı').slice(0,80);
 const id='trusted_'+createHash('sha256').update(`${type}:${eventId}:${target}`).digest('hex');
 const ref=db.doc(`users/${target}/notifications/${id}`);
 try {await ref.create({type,actorId:actor,sourceId:source||null,title:title(name),body:String(body||'Görmek için dokun.').slice(0,500),read:false,createdAt:FieldValue.serverTimestamp()});}
 catch(e){if(e.code!==6&&e.code!=='already-exists')throw e;}
}
async function directMessage(event,db=getFirestore()) {
 const m=event.data?.data();if(!m||m.deleted||m.type==='private_photo'||m.source==='notification_reply'||!key(m.senderId))return;
 const t=(await db.doc(`chat_threads/${event.params.threadId}`).get()).data();
 if(t?.type!=='direct'||!Array.isArray(t.memberIds)||t.memberIds.length!==2||!t.memberIds.includes(m.senderId))return;
 const body=m.type==='text'?String(m.text||''):m.type==='audio'?'Sesli mesaj':m.type==='image'?'Fotoğraf':'Paylaşılan içerik';
 await deliver(db,{target:t.memberIds.find(u=>u!==m.senderId),actor:m.senderId,type:'message',source:event.params.threadId,title:n=>`${n} sana mesaj gönderdi`,body,eventId:event.id});
}
exports.trustedDirectMessage=onDocumentCreated('chat_threads/{threadId}/messages/{messageId}',event=>directMessage(event));
exports.trustedFollow=onDocumentCreated('users/{target}/followers/{actor}',async event=>{
 const d=event.data?.data();if(d?.userId!==event.params.actor)return;
 await deliver(getFirestore(),{...event.params,type:'follow',source:event.params.actor,title:n=>`${n} seni takip etmeye başladı`,eventId:event.id});
});
exports.trustedPostLike=onDocumentCreated('posts/{postId}/likes/{actor}',async event=>{
 const db=getFirestore(),p=(await db.doc(`posts/${event.params.postId}`).get()).data();
 if(!p||event.data?.data()?.userId!==event.params.actor)return;
 await deliver(db,{target:p.userId,actor:event.params.actor,type:'like',source:event.params.postId,title:n=>`${n} gönderini beğendi`,eventId:event.id});
});
exports.trustedPostComment=onDocumentCreated('posts/{postId}/comments/{commentId}',async event=>{
 const db=getFirestore(),p=(await db.doc(`posts/${event.params.postId}`).get()).data(),d=event.data?.data();if(!p||!d)return;
 await deliver(db,{target:p.userId,actor:d.userId,type:'comment',source:event.params.postId,title:n=>`${n} gönderine yorum yaptı`,body:d.text,eventId:event.id});
});
exports.trustedEventAttendance=onDocumentWritten('social_events/{eventId}/attendance/{actor}',async event=>{
 const d=event.data?.after.data(),before=event.data?.before.data();
 if(!d||d.status===before?.status||!['going','interested','private'].includes(d.status))return;
 const db=getFirestore(),e=(await db.doc(`social_events/${event.params.eventId}`).get()).data();if(!e)return;
 await deliver(db,{target:e.hostId,actor:event.params.actor,type:'event_join',source:event.params.eventId,title:n=>`${n} etkinliğine katılım bildirdi`,body:e.title,eventId:event.id});
});
exports.trustedStoryInteraction=onDocumentWritten('stories/{storyId}/interactions/{actor}',async event=>{
 const d=event.data?.after.data(),before=event.data?.before.data()||{};if(!d)return;
 const like=d.liked===true&&before.liked!==true,reaction=d.reaction&&d.reaction!==before.reaction;if(!like&&!reaction)return;
 const db=getFirestore(),s=(await db.doc(`stories/${event.params.storyId}`).get()).data();if(!s||s.expiresAt?.toMillis()<=Date.now())return;
 await deliver(db,{target:s.userId,actor:event.params.actor,type:reaction?'story_reaction':'story_like',source:event.params.storyId,title:n=>`${n} storyinle etkileşimde bulundu`,body:reaction?d.reaction:'Storyini beğendi.',eventId:event.id});
});
exports._directMessage=directMessage;
exports.trustedStoryMention=onDocumentCreated('stories/{storyId}',async event=>{
 const s=event.data?.data();if(!s||!Array.isArray(s.mentionedUserIds))return;
 const db=getFirestore();
 for(const target of [...new Set(s.mentionedUserIds)].slice(0,20))await deliver(db,{target,actor:s.userId,type:'story_mention',source:event.params.storyId,title:n=>`${n} storyinde senden bahsetti`,eventId:event.id});
});
exports.trustedEventMemory=onDocumentCreated('event_memories/{memoryId}',async event=>{
 const m=event.data?.data();if(!m||!key(m.eventId))return;
 const db=getFirestore(),e=(await db.doc(`social_events/${m.eventId}`).get()).data();if(!e||!e.participantIds?.includes(m.userId))return;
 for(const target of [...new Set(e.participantIds)])await deliver(db,{target,actor:m.userId,type:'event_memory',source:m.eventId,title:n=>`${n} etkinliğe yeni bir anı ekledi`,body:e.title,eventId:event.id});
});
exports.trustedPostTag=onDocumentCreated('posts/{postId}/tags/{target}',async event=>{
 const d=event.data?.data();if(!d||d.userId!==event.params.target)return;
 await deliver(getFirestore(),{target:event.params.target,actor:d.taggedBy,type:'tag',source:event.params.postId,title:n=>`${n} bir gönderide seni etiketledi`,eventId:event.id});
});
