const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,serverTimestamp,writeBatch}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
(async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-tbt',firestore:{host:'127.0.0.1',port:8080},storage:{host:'127.0.0.1',port:9199}});
 const db=uid=>env.authenticatedContext(uid).firestore(), st=uid=>env.authenticatedContext(uid).storage();
 try {
  await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'travel_plans/chat'),{ownerId:'owner',memberIds:['owner','member'],isPublic:true}));
  const path='route_chat/chat/member/voice/audio.m4a';
  await assertSucceeds(uploadBytes(ref(st('member'),path),new Uint8Array([1,2]),{contentType:'audio/mp4'}));
  await assertSucceeds(getBytes(ref(st('owner'),path)));
  await assertFails(getBytes(ref(st('outside'),path)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(),path)));
  await assertFails(uploadBytes(ref(st('owner'),'route_chat/chat/member/spoof/audio.m4a'),new Uint8Array([1]),{contentType:'audio/mp4'}));
  await assertFails(uploadBytes(ref(st('member'),'route_chat/chat/member/bad/audio.m4a'),new Uint8Array([1]),{contentType:'text/html'}));
  await assertFails(uploadBytes(ref(st('member'),path),new Uint8Array([1]),{contentType:'audio/mp4'}));
  const message={senderId:'member',senderName:'Member',text:'Sesli mesaj',type:'audio',storagePath:path,createdAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(db('member'),'travel_plans/chat/messages/voice'),message));
  await assertFails(setDoc(doc(db('outside'),'travel_plans/chat/messages/outside'),{...message,senderId:'outside'}));
  await assertFails(setDoc(doc(db('member'),'travel_plans/chat/messages/spoof'),{...message,senderId:'owner'}));
  await assertFails(getDoc(doc(db('outside'),'travel_plans/chat/messages/voice')));
  const batch=writeBatch(db('member'));
  const mediaPath='route_albums/chat/member/image/media.jpg';
  batch.set(doc(db('member'),'travel_plans/chat/messages/image'),{...message,text:'Fotoğraf',type:'image',storagePath:mediaPath,inAlbum:true});
  batch.set(doc(db('member'),'travel_plans/chat/album/image'),{ownerId:'member',ownerName:'Member',storagePath:mediaPath,thumbnailPath:'',kind:'image',allowExport:false,createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertSucceeds(updateDoc(doc(db('owner'),'travel_plans/chat'),{memberIds:['owner']}));
  await assertFails(getBytes(ref(st('member'),path)));
  await assertFails(getDoc(doc(db('member'),'travel_plans/chat/messages/voice')));
  console.log('PASS route chat: member upload/read, outsider/anonymous/revoked denied, spoofing/MIME/overwrite denied, atomic album + message');
 } finally {await env.cleanup();}
})().catch(e=>{console.error(e);process.exitCode=1;});
