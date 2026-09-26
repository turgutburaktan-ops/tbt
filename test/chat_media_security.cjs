const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {ref,uploadBytes,getBytes,updateMetadata,listAll}=require('firebase/storage');
const {doc,setDoc,updateDoc}=require('firebase/firestore');
const {_finalizeChatMediaHandler,_sealChatFile}=require('../functions/chat_media_security');
let env;
const bucket='gs://demo-tbt-access.appspot.com';
const path='private_chat/thread/alice/message/media.jpg';
const legacy='users/alice/chat/thread/old.jpg';
const bytes=new Uint8Array([1,2,3]);
const media=(uid,p=path)=>ref((uid?env.authenticatedContext(uid):env.unauthenticatedContext()).storage(bucket),p);
const seed=async(callback)=>env.withSecurityRulesDisabled(callback);
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-tbt-access',
  firestore:{rules:fs.readFileSync('firestore.rules','utf8')},
  storage:{rules:fs.readFileSync('storage.rules','utf8')}});
 await seed(async c=>{
  await setDoc(doc(c.firestore(),'chat_threads/thread'),{memberIds:['alice','bob'],deletedMessageIds:[]});
  for(const id of ['message','old']) await setDoc(doc(c.firestore(),'chat_threads/thread/messages/'+id),{senderId:'alice',type:'image',deleted:false});
  for(const p of [path,legacy]) await uploadBytes(ref(c.storage(bucket),p),bytes,{contentType:'image/jpeg',customMetadata:{chatSealed:'true',chatMessageId:'old'}});
  await uploadBytes(ref(c.storage(bucket),'users/alice/profile/avatar.jpg'),bytes,{contentType:'image/jpeg'});
 });
});
after(async()=>env?.cleanup());
test('only current chat members can download new and legacy media',async()=>{
 for(const p of [path,legacy]) {
  await assertSucceeds(getBytes(media('alice',p)));
  await assertSucceeds(getBytes(media('bob',p)));
  await assertFails(getBytes(media('outsider',p)));
  await assertFails(getBytes(media(null,p)));
 }
 await assertFails(listAll(media('bob','private_chat/thread/alice/message')));
 await assertSucceeds(getBytes(media(null,'users/alice/profile/avatar.jpg')));
});
test('removed members and deleted messages fail closed',async()=>{
 await seed(c=>updateDoc(doc(c.firestore(),'chat_threads/thread'),{memberIds:['alice']}));
 await assertFails(getBytes(media('bob')));
 await seed(c=>updateDoc(doc(c.firestore(),'chat_threads/thread'),{memberIds:['alice','bob'],deletedMessageIds:['message']}));
 await assertFails(getBytes(media('bob')));
 await seed(c=>updateDoc(doc(c.firestore(),'chat_threads/thread'),{deletedMessageIds:[]}));
 await seed(c=>updateDoc(doc(c.firestore(),'chat_threads/thread/messages/message'),{deleted:true}));
 await assertFails(getBytes(media('alice')));
 await seed(c=>updateDoc(doc(c.firestore(),'chat_threads/thread/messages/message'),{deleted:false}));
});
test('uploads are owner-scoped and immutable; clients cannot mark files sealed',async()=>{
 const fresh='private_chat/thread/alice/fresh/media.jpg';
 await assertSucceeds(uploadBytes(media('alice',fresh),bytes,{contentType:'image/jpeg'}));
 await assertFails(getBytes(media('alice',fresh)));
 await assertFails(uploadBytes(media('bob','private_chat/thread/alice/forged/media.jpg'),bytes,{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(media('outsider','private_chat/thread/outsider/forged/media.jpg'),bytes,{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(media('alice','users/alice/chat/thread/new.jpg'),bytes,{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(media('alice','private_chat/thread/alice/forged/media.jpg'),bytes,{contentType:'image/jpeg',customMetadata:{chatSealed:'true'}}));
 // Reserved download tokens are not exposed to Storage rule evaluation.
 // The server finalizer strips them; reads stay denied until the server seal.
 await assertSucceeds(uploadBytes(media('alice','private_chat/thread/alice/token/media.jpg'),bytes,{contentType:'image/jpeg',customMetadata:{firebaseStorageDownloadTokens:'public'}}));
 await assertFails(getBytes(media('bob','private_chat/thread/alice/token/media.jpg')));
 await assertFails(updateMetadata(media('alice'),{customMetadata:{firebaseStorageDownloadTokens:'public'}}));
 await assertFails(uploadBytes(media('alice'),bytes,{contentType:'image/jpeg'}));
 await assertFails(uploadBytes(media('alice','private_chat/thread/alice/bad/audio.m4a'),bytes,{contentType:'application/octet-stream'}));
 await assertSucceeds(uploadBytes(media('alice','private_chat/thread/alice/voice/audio.m4a'),bytes,{contentType:'audio/mp4'}));
});
test('finalizer binds object path to authenticated member; emits no bearer URL',async()=>{
 let selected, metadata={metageneration:'1',metadata:{firebaseStorageDownloadTokens:'secret'}};
 const file={getMetadata:async()=>[metadata],setMetadata:async(m,options)=>{
  assert.equal(options.ifMetagenerationMatch,metadata.metageneration);metadata={...m,metageneration:'2'};
 }};
 const db={doc:()=>({get:async()=>({data:()=>({memberIds:['alice','bob']})})})};
 const bucket={file:p=>{selected=p;return file;}};
 const data={threadId:'thread',messageId:'message',fileName:'media.jpg'};
 await assert.rejects(()=>_finalizeChatMediaHandler({data},db,bucket),{code:'unauthenticated'});
 await assert.rejects(()=>_finalizeChatMediaHandler({auth:{uid:'outsider'},data},db,bucket),{code:'permission-denied'});
 await assert.rejects(()=>_finalizeChatMediaHandler({auth:{uid:'alice'},data:{...data,threadId:'../other'}},db,bucket),{code:'invalid-argument'});
 const result=await _finalizeChatMediaHandler({auth:{uid:'alice'},data:{...data,uid:'bob'}},db,bucket);
 assert.equal(selected,path);assert.match(result.storageUrl,/^gs:\/\//);assert(!result.storageUrl.includes('token'));
 assert.equal(metadata.metadata.firebaseStorageDownloadTokens,null);assert.equal(metadata.metadata.chatSealed,'true');
});
test('sealing retries metadata races and refuses token persistence',async()=>{
 let n=0;
 await _sealChatFile({getMetadata:async()=>[{metageneration:'2',metadata:{}}],setMetadata:async()=>{if(n++===0)throw {code:412};}});
 assert.equal(n,2);
 await assert.rejects(()=>_sealChatFile({getMetadata:async()=>[{metageneration:'1',metadata:{firebaseStorageDownloadTokens:'still-open'}}],setMetadata:async()=>{}}));
});
