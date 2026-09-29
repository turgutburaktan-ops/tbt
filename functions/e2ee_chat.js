const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const uidOf=r=>r.auth?.uid||fail('unauthenticated','Giriş yapmalısın.');
const id=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{1,160}$/.test(v)?v:fail('invalid-argument','Geçersiz kimlik.');
const exact=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k));
function base64(v,min,max=min){
 if(typeof v!=='string'||v.length>Math.ceil(max/3)*4||!/^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(v))fail('invalid-argument','Geçersiz şifreleme verisi.');
 const bytes=Buffer.from(v,'base64');if(bytes.length<min||bytes.length>max||bytes.toString('base64')!==v)fail('invalid-argument','Geçersiz şifreleme boyutu.');return v;
}
function validateBundle(d){
 if(!exact(d,['version','registrationId','deviceId','identityKey','signedPreKey','preKeys'])||d.version!==1||d.deviceId!==1||!Number.isInteger(d.registrationId)||d.registrationId<1||d.registrationId>16380)fail('invalid-argument','Geçersiz cihaz kaydı.');
 base64(d.identityKey,33);
 const s=d.signedPreKey;
 if(!exact(s,['id','publicKey','signature'])||s.id!==1)fail('invalid-argument','Geçersiz imzalı anahtar.');
 base64(s.publicKey,33);base64(s.signature,64);
 if(!Array.isArray(d.preKeys)||d.preKeys.length>100)fail('invalid-argument','Geçersiz ön anahtarlar.');
 const ids=new Set();for(const p of d.preKeys){if(!exact(p,['id','publicKey'])||!Number.isInteger(p.id)||p.id<1||p.id>100||ids.has(p.id))fail('invalid-argument','Yinelenen ön anahtar.');ids.add(p.id);base64(p.publicKey,33);}
}
function validatePacket(packet,uid,members){
 if(!exact(packet,['version','senderId','envelopes'])||packet.version!==1||packet.senderId!==uid||!packet.envelopes||Array.isArray(packet.envelopes))fail('invalid-argument','Geçersiz şifreli mesaj.');
 const expected=members.filter(m=>m!==uid).sort(), actual=Object.keys(packet.envelopes).sort();
 if(JSON.stringify(actual)!==JSON.stringify(expected))fail('failed-precondition','Sohbet üyeleri değişti. Mesajı yeniden hazırla.');
 for(const p of Object.values(packet.envelopes)){if(!exact(p,['type','body'])||![2,3].includes(p.type))fail('invalid-argument','Geçersiz mesaj zarfı.');base64(p.body,1,65536);}
 if(Buffer.byteLength(JSON.stringify(packet))>700000)fail('invalid-argument','Şifreli mesaj çok büyük.');
}
function canonical(v){if(Array.isArray(v))return v.map(canonical);if(v&&typeof v==='object')return Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])]));return v;}
function active(p){return p&&!p.disabled&&!p.banned&&!['frozen','deleting','deleted'].includes(p.accountStatus);}
async function memberContext(tx,db,threadId,uid,scope='chat'){
 const collections={chat:'chat_threads',route:'travel_plans',event:'social_events'};
 if(!Object.hasOwn(collections,scope))fail('invalid-argument','Geçersiz sohbet türü.');
 const ref=db.doc(`${collections[scope]}/${id(threadId)}`),raw=(await tx.get(ref)).data();
 const members=scope==='event'?[...new Set([raw?.hostId,...(raw?.participantIds||[])])]:raw?.memberIds;
 const t=raw&&{...raw,type:scope==='chat'?raw.type:'group',memberIds:members};
 if(!t||!['direct','group'].includes(t.type)||!Array.isArray(members)||!members.includes(uid)||members.length<2||members.length>50||new Set(members).size!==members.length||raw.accountFrozen===true)fail('permission-denied','Bu sohbete erişimin yok.');
 if(scope==='event'&&raw.status!=='open')fail('permission-denied','Etkinlik sohbeti kapalı.');
 const profile=(await tx.get(db.doc(`users/${uid}`))).data();if(!active(profile))fail('permission-denied','Hesap kullanılamıyor.');
 if(t.type==='direct'){
  if(t.requestStatus&&t.requestStatus!=='accepted')fail('failed-precondition','Önce mesaj isteği kabul edilmeli.');
  const peer=members.find(x=>x!==uid);
  const [a,b,p]=await Promise.all([tx.get(db.doc(`users/${uid}/blocked/${peer}`)),tx.get(db.doc(`users/${peer}/blocked/${uid}`)),tx.get(db.doc(`users/${peer}`))]);
  if(a.exists||b.exists||!active(p.data()))fail('permission-denied','Bu kullanıcıyla mesajlaşma kullanılamıyor.');
 }
 return {ref,t,scope};
}
async function register(request,db=getFirestore()){
 const uid=uidOf(request),d=request.data;validateBundle(d);
 return db.runTransaction(async tx=>{
  const ref=db.doc(`e2ee_identities/${uid}`),[current,profile]=await Promise.all([tx.get(ref),tx.get(db.doc(`users/${uid}`))]);
  if(!active(profile.data()))fail('permission-denied','Hesap kullanılamıyor.');
  if(current.exists){const c=current.data();if(c.identityKey!==d.identityKey||c.registrationId!==d.registrationId||JSON.stringify(canonical(c.signedPreKey))!==JSON.stringify(canonical(d.signedPreKey)))fail('failed-precondition','Bu hesabın anahtarı başka cihazda. Mevcut anahtar değiştirilemez.');return {ok:true};}
  tx.create(ref,{version:1,deviceId:1,registrationId:d.registrationId,identityKey:d.identityKey,signedPreKey:d.signedPreKey,createdAt:FieldValue.serverTimestamp()});
  for(const p of d.preKeys)tx.create(db.doc(`e2ee_identities/${uid}/prekeys/${p.id}`),p);
  return {ok:true};
 });
}
async function claim(request,db=getFirestore()){
 const uid=uidOf(request),d=request.data||{},peer=id(d.peerId);
 return db.runTransaction(async tx=>{
  const {t}=await memberContext(tx,db,d.threadId,uid,d.scope);
  if(peer===uid||!t.memberIds.includes(peer))fail('permission-denied','Anahtar alıcısı sohbette değil.');
  const ref=db.doc(`e2ee_identities/${peer}`),bundle=(await tx.get(ref)).data();
  if(!bundle)fail('failed-precondition','Diğer kişinin şifreli mesajlaşmayı bu sürümde açması gerekiyor.');
  const rateRef=db.doc(`e2ee_key_limits/${uid}`),rate=(await tx.get(rateRef)).data()||{},now=Date.now();
  const count=now-Number(rate.start||0)<60000?Number(rate.count||0):0;
  if(count>=200)fail('resource-exhausted','Anahtar isteği sınırı aşıldı.');
  const prekeys=d.consumePreKey===false?{docs:[]}:await tx.get(db.collection(`e2ee_identities/${peer}/prekeys`).limit(1));
  const pre=prekeys.docs[0];
  tx.set(rateRef,{start:count?rate.start:now,count:count+1});
  if(pre)tx.delete(pre.ref);
  return {version:1,deviceId:1,registrationId:bundle.registrationId,identityKey:bundle.identityKey,signedPreKey:bundle.signedPreKey,preKey:pre?pre.data():null};
 });
}
async function send(request,db=getFirestore()){
 const uid=uidOf(request),d=request.data||{};
 if(!d||!['threadId','messageId','packet'].every(k=>Object.hasOwn(d,k))||Object.keys(d).some(k=>!['threadId','messageId','packet','scope','kind','pollOptionCount','revision'].includes(k)))fail('invalid-argument','Yalnız şifreli mesaj kabul edilir.');
 const messageId=id(d.messageId),kind=d.kind||'text',revision=d.revision||0;
 if(!['text','image','audio','video','location','share','poll'].includes(kind)||!Number.isInteger(revision)||revision<0||revision>100)fail('invalid-argument','Geçersiz şifreli mesaj türü.');
 if(kind==='poll'&&(!Number.isInteger(d.pollOptionCount)||d.pollOptionCount<2||d.pollOptionCount>6))fail('invalid-argument','Geçersiz anket.');
 return db.runTransaction(async tx=>{
  const {ref,t}=await memberContext(tx,db,d.threadId,uid,d.scope);
  validatePacket(d.packet,uid,t.memberIds);
  const identities=await Promise.all(t.memberIds.map(m=>tx.get(db.doc(`e2ee_identities/${m}`))));
  if(identities.some(i=>!i.exists))fail('failed-precondition','Tüm katılımcıların şifreleme anahtarı gerekli.');
  const message=ref.collection(d.scope==='event'?'chat':'messages').doc(messageId),existing=await tx.get(message);
  const hash=createHash('sha256').update(JSON.stringify(canonical(d.packet))).digest('hex');
  const rateRef=db.doc(`e2ee_send_limits/${uid}`),rate=(await tx.get(rateRef)).data()||{},now=Date.now();
  const count=now-Number(rate.start||0)<60000?Number(rate.count||0):0;
  if(existing.exists){
   const m=existing.data();
   if(m.senderId===uid&&m.ciphertextHash===hash)return {ok:true,alreadySent:true};
   if(m.senderId!==uid||m.deleted||m.type!=='e2ee'||m.encryptedKind!=='text'||kind!=='text'||revision!==(m.revision||0)+1||!m.createdAt?.toMillis||Date.now()-m.createdAt.toMillis()>15*60000)fail('already-exists','Mesaj düzenlenemiyor veya değişmiş.');
   if(count>=40)fail('resource-exhausted','Biraz bekleyip tekrar dene.');
   tx.set(rateRef,{start:count?rate.start:now,count:count+1});
   tx.update(message,{e2ee:d.packet,ciphertextHash:hash,revision,editedAt:FieldValue.serverTimestamp()});
   return {ok:true};
  }
  if(revision!==0)fail('not-found','Düzenlenecek mesaj bulunamadı.');
  if(count>=40)fail('resource-exhausted','Biraz bekleyip tekrar dene.');
  tx.set(rateRef,{start:count?rate.start:now,count:count+1});
  tx.create(message,{revision:0,encryptedKind:kind,...(kind==='poll'?{pollOptionCount:d.pollOptionCount,votes:{},closed:false}:{}),senderId:uid,senderName:'Üye',type:'e2ee',text:'Şifreli mesaj',e2ee:d.packet,ciphertextHash:hash,deleted:false,createdAt:FieldValue.serverTimestamp()});
  tx.update(ref,{e2eeVersion:1,...(!d.scope||d.scope==='chat'?{lastMessageId:messageId,lastMessage:'Şifreli mesaj',lastSenderId:uid,lastMessageAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()}: {})});
  return {ok:true};
 });
}
const options={region:'europe-west1',maxInstances:10,timeoutSeconds:60};
exports.registerE2eeIdentity=onCall(options,r=>register(r));
exports.claimE2eePreKey=onCall(options,r=>claim(r));
exports.sendE2eeMessage=onCall(options,r=>send(r));
exports._register=register;exports._claim=claim;exports._send=send;exports._validateBundle=validateBundle;exports._validatePacket=validatePacket;
