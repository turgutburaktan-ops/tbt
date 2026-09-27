const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const deny=message=>{throw new HttpsError('permission-denied',message);};
const validId=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,200}$/.test(v);
async function reply(request,db=getFirestore()){
  const uid=request.auth?.uid;if(!uid)throw new HttpsError('unauthenticated','Giriş yapmalısın.');
  const d=request.data||{},text=typeof d.text==='string'?d.text.trim():'';
  if(!validId(d.threadId)||!validId(d.notificationId)||!text||text.length>1500)throw new HttpsError('invalid-argument','Geçersiz mesaj.');
  const messageId='nr_'+createHash('sha256').update(`${uid}:${d.notificationId}`).digest('hex');
  const threadRef=db.doc(`chat_threads/${d.threadId}`),msg=threadRef.collection('messages').doc(messageId),notification=db.doc(`users/${uid}/notifications/${d.notificationId}`);
  return db.runTransaction(async tx=>{
    const [thread,origin,existing,profile]=await Promise.all([tx.get(threadRef),tx.get(notification),tx.get(msg),tx.get(db.doc(`users/${uid}`))]);
    const t=thread.data(),n=origin.data(),p=profile.data();
    if(!p||p.disabled||p.banned||['frozen','deleting','deleted'].includes(p.accountStatus))deny('Hesap kullanılamıyor.');
    if(!t||!Array.isArray(t.memberIds)||!t.memberIds.includes(uid)||!n||n.sourceId!==d.threadId||!['message','group_message'].includes(n.type))deny('Bu bildirime yanıt veremezsin.');
    if(t.type!=='group'&&(t.type!=='direct'||t.memberIds.length!==2))deny('Geçersiz sohbet.');
    if(!t.memberIds.includes(n.actorId)||n.actorId===uid)deny('Bildirim göndereni bu sohbete ait değil.');
    const peers=t.memberIds.filter(v=>v!==uid);
    const states=await Promise.all(peers.map(async peer=>{
      const [person,a,b]=await Promise.all([tx.get(db.doc(`users/${peer}`)),tx.get(db.doc(`users/${uid}/blocked/${peer}`)),tx.get(db.doc(`users/${peer}/blocked/${uid}`))]);
      return {person:person.data(),blocked:a.exists||b.exists};
    }));
    if(t.type==='direct'&&states.some(s=>s.blocked||!s.person||s.person.disabled||s.person.banned||['frozen','deleting','deleted'].includes(s.person.accountStatus)))deny('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    if(existing.exists){if(existing.data().text!==text)throw new HttpsError('already-exists','Bu bildirime zaten yanıt verdin.');return {id:messageId,alreadySent:true};}
    const rate=db.doc(`notification_reply_limits/${uid}`),rateSnap=await tx.get(rate),now=Date.now();
    const fresh=now-Number(rateSnap.data()?.start||0)>=60000,count=fresh?0:Number(rateSnap.data()?.count||0);
    if(count>=20)throw new HttpsError('resource-exhausted','Biraz bekleyip tekrar dene.');
    tx.set(rate,{start:fresh?now:rateSnap.data().start,count:count+1});
    const name=String(p.displayName||p.username||'Üye').slice(0,80);
    tx.create(msg,{senderId:uid,senderName:name,text,type:'text',deleted:false,createdAt:FieldValue.serverTimestamp(),source:'notification_reply'});
    tx.update(threadRef,{lastMessageId:messageId,lastMessage:text,lastSenderId:uid,lastMessageAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    tx.update(notification,{read:true});
    if(t.type==='direct')tx.create(db.doc(`users/${peers[0]}/notifications/${messageId}`),{type:'message',sourceId:d.threadId,actorId:uid,title:name,body:text.slice(0,160),read:false,createdAt:FieldValue.serverTimestamp()});
    return {id:messageId,alreadySent:false};
  });
}
exports.replyToNotification=onCall({region:'europe-west1'},r=>reply(r));
exports._reply=reply;

