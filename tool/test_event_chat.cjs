const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,serverTimestamp}=require('firebase/firestore');
const {ref,uploadBytes,getBytes}=require('firebase/storage');
(async()=>{
 const env=await initializeTestEnvironment({projectId:'demo-tbt',firestore:{host:'127.0.0.1',port:8080},storage:{host:'127.0.0.1',port:9199}});
 const ctx=Object.fromEntries(['owner','member','outside'].map(uid=>[uid,env.authenticatedContext(uid)]));
 const db=uid=>ctx[uid].firestore(),st=uid=>ctx[uid].storage();
 const event={hostId:'owner',participantIds:['owner','member'],visibility:'public',status:'open',startsAt:new Date(Date.now()+3600000)};
 const seed=e=>env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'social_events/chat-test'),e));
 const message=(extra={})=>({senderId:'member',senderName:'Member',text:'Merhaba',createdAt:serverTimestamp(),...extra});
 const put=(id,data,user='member')=>setDoc(doc(db(user),'social_events/chat-test/chat/'+id),data);
 try {
  await seed(event);
  await assertSucceeds(put('legacy',message()));
  await assertSucceeds(getDoc(doc(db('owner'),'social_events/chat-test/chat/legacy')));
  await assertFails(getDoc(doc(db('outside'),'social_events/chat-test/chat/legacy')));
  await assertFails(put('outsider',message({senderId:'outside'}),'outside'));
  await assertFails(put('spoof',message({senderId:'owner'})));
  await assertSucceeds(put('reply',message({type:'text',reply:{id:'legacy',name:'Member',text:'Merhaba'}})));
  await assertFails(put('badreply',message({reply:{id:'missing',name:'Member',text:'Fake'}})));
  await assertSucceeds(put('location',message({type:'location',latitude:38.67,longitude:39.22})));
  await assertFails(put('badlocation',message({type:'location',latitude:100,longitude:0})));
  const path='event_chat/chat-test/member/voice/audio.m4a';
  await assertSucceeds(uploadBytes(ref(st('member'),path),new Uint8Array([1,2]),{contentType:'audio/mp4'}));
  await assertSucceeds(put('voice',message({type:'audio',text:'Sesli mesaj',storagePath:path,durationMs:1000})));
  await assertFails(put('crosspath',message({type:'audio',storagePath:path,durationMs:1000})));
  await assertSucceeds(getBytes(ref(st('owner'),path)));
  await assertFails(getBytes(ref(st('outside'),path)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(),path)));
  await assertFails(uploadBytes(ref(st('member'),path),new Uint8Array([1]),{contentType:'audio/mp4'}));
  await assertFails(uploadBytes(ref(st('owner'),'event_chat/chat-test/member/spoof/audio.m4a'),new Uint8Array([1]),{contentType:'audio/mp4'}));
  await assertFails(uploadBytes(ref(st('member'),'event_chat/chat-test/member/bad/audio.m4a'),new Uint8Array([1]),{contentType:'text/html'}));
  for(const [type,ext,mime] of [['image','jpg','image/jpeg'],['video','mp4','video/mp4']]){
    const media='event_chat/chat-test/member/'+type+'/media.'+ext;
    await assertSucceeds(uploadBytes(ref(st('member'),media),new Uint8Array([1,2]),{contentType:mime}));
    await assertSucceeds(put(type,message({type,storagePath:media})));
  }
  await seed({...event,status:'cancelled'});
  await assertFails(put('cancelled',message()));
  await assertFails(uploadBytes(ref(st('member'),'event_chat/chat-test/member/cancel/audio.m4a'),new Uint8Array([1]),{contentType:'audio/mp4'}));
  await assertSucceeds(getBytes(ref(st('owner'),path)));
  await seed({...event,participantIds:['owner']});
  await assertFails(getBytes(ref(st('member'),path)));
  await assertFails(getDoc(doc(db('member'),'social_events/chat-test/chat/legacy')));
  console.log('PASS event chat: legacy messages, replies, location, image/video/voice, membership, revocation, cancellation, spoofing, path and MIME checks');
 } finally {await env.cleanup();}
})().catch(e=>{console.error(e);process.exitCode=1;});
