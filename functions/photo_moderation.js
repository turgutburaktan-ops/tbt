const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated, onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {getAuth} = require('firebase-admin/auth');
const {getApp} = require('firebase-admin/app');
const {randomUUID, createHash} = require('node:crypto');
const {isNamedAdmin} = require('./broadcast_policy');
const {classify, ownedPaths, photoPath, strikeChange, closureStatus} = require('./photo_moderation_policy');
const BUCKET = 'en-iyi-cekim-noktasi.firebasestorage.app';
const opts = {region:'europe-west1', timeoutSeconds:300, memory:'512MiB', maxInstances:5};
const stamp = () => FieldValue.serverTimestamp();
const hash = s => createHash('sha256').update(s).digest('hex');
function validId(v) { if (typeof v !== 'string' || !/^[\w-]{1,128}$/.test(v)) throw new HttpsError('invalid-argument','Geçersiz kimlik.'); return v; }
function admin(r) { if (!isNamedAdmin(r.auth)) throw new HttpsError('permission-denied','Yönetici yetkisi gerekli.'); return r.auth.uid; }
function reason(v) { const s=String(v||'').trim(); if(s.length<5||s.length>500) throw new HttpsError('invalid-argument','5–500 karakterlik gerekçe yaz.'); return s; }
function notify(tx, db, uid, key, body) {
  tx.set(db.doc(`users/${uid}/notifications/photo_${key}`), {type:'photo_moderation', title:'Paylaşım denetimi', body, actorId:'system', sourceId:key, read:false, createdAt:stamp()});
}
async function safeSearch(path) {
  const access = await getApp().options.credential.getAccessToken();
  const response = await fetch('https://vision.googleapis.com/v1/images:annotate', {
    method:'POST', headers:{Authorization:`Bearer ${access.access_token}`, 'Content-Type':'application/json'},
    body:JSON.stringify({requests:[{image:{source:{gcsImageUri:`gs://${BUCKET}/${path}`}},features:[{type:'SAFE_SEARCH_DETECTION'}]}]}),
    signal:AbortSignal.timeout(45000),
  });
  const result=await response.json();
  if(!response.ok || result.responses?.[0]?.error) throw Error(`vision_${result.responses?.[0]?.error?.code || response.status}`);
  return result.responses?.[0]?.safeSearchAnnotation;
}
// Factory exposes real transitions to emulator tests with fake Vision/media only.
function createEngine({db=getFirestore(), auth=getAuth(), bucket=getStorage().bucket(BUCKET), scan=safeSearch}={}) {
  async function enqueue(id, post) {
    if (!post?.userId || (post.mediaType || 'image') !== 'image') return;
    await db.runTransaction(async tx=>{
      const ref=db.doc(`photo_moderation/${id}`), old=await tx.get(ref);
      if(old.exists) return; // Restores and duplicate delivery never create a second strike.
      tx.create(ref,{postId:id, userId:post.userId, status:'scanning', desiredHidden:false, workPending:true,
        attempts:0, leaseUntil:0, createdAt:stamp(), updatedAt:stamp(), imageUrl:post.imageUrl||'', storagePath:post.storagePath||''});
    });
  }
  async function media(post, hidden) {
    const replacements={};
    for(const path of ownedPaths(post)) {
      const file=bucket.file(path);
      let metadata;
      try { [metadata]=await file.getMetadata(); } catch(e) { if(Number(e.code)===404) continue; throw e; }
      const token=hidden ? null : (metadata.metadata?.moderationBlocked==='true' ? randomUUID() : metadata.metadata?.firebaseStorageDownloadTokens || randomUUID());
      await file.setMetadata({cacheControl:'private, no-store, max-age=0',metadata:{...metadata.metadata,
        moderationBlocked:hidden?'true':null, firebaseStorageDownloadTokens:token}});
      if(token) replacements[path]=`https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
    }
    const result={...post};
    for(const [p,u] of [['storagePath','imageUrl'],['thumbnailStoragePath','thumbnailUrl'],['videoStoragePath','videoUrl']]) if(replacements[post[p]]) result[u]=replacements[post[p]];
    return result;
  }
  async function hide(id) {
    const postRef=db.doc(`posts/${id}`), archive=db.doc(`photo_moderation_archive/${id}`);
    // Archive before changing media or removing from public queries. No destructive data deletion.
    await db.runTransaction(async tx=>{
      const [post,old]=await Promise.all([tx.get(postRef),tx.get(archive)]);
      if(post.exists && !old.exists) tx.create(archive,{post:post.data(),createdAt:stamp()});
    });
    const saved=await archive.get();
    if(!saved.exists) return;
    await media(saved.data().post,true); // Revoke public download tokens, not only the feed document.
    await db.runTransaction(async tx=>{
      const post=await tx.get(postRef);
      let memory;
      if(saved.data().post.sourceType==='event_memory') memory=await tx.get(db.doc(`event_memories/${id}`));
      if(memory?.exists) { tx.set(archive,{memory:memory.data()},{merge:true}); tx.delete(memory.ref); }
      if(post.exists) tx.delete(postRef);
    });
  }
  async function restore(id) {
    const ref=db.doc(`photo_moderation_archive/${id}`), saved=await ref.get();
    if(!saved.exists) return;
    const p=await media(saved.data().post,false);
    await db.runTransaction(async tx=>{
      const publicPost=await tx.get(db.doc(`posts/${id}`));
      if(!publicPost.exists) tx.create(db.doc(`posts/${id}`),p);
      if(saved.data().memory) tx.set(db.doc(`event_memories/${id}`),{...saved.data().memory,imageUrl:p.imageUrl});
      tx.delete(ref);
    });
  }
  async function process(id) {
    const ref=db.doc(`photo_moderation/${id}`), lease=randomUUID();
    const acquired=await db.runTransaction(async tx=>{
      const s=await tx.get(ref), d=s.data();
      if(!d?.workPending || (d.leaseUntil>Date.now() || d.nextAttemptAt>Date.now())) return false;
      const accountRef=db.doc(`photo_moderation_accounts/${d.userId}`), account=(await tx.get(accountRef)).data();
      if(account?.operationUntil>Date.now() || ['closing','reopening'].includes(account?.closureStatus)) return false;
      tx.set(accountRef,{userId:d.userId,operationLease:lease,operationUntil:Date.now()+360000},{merge:true});
      tx.update(ref,{lease,leaseUntil:Date.now()+360000}); return d.userId;
    });
    if(!acquired) return;
    try {
      let d=(await ref.get()).data();
      if(d.status==='scanning') {
        const post=(await db.doc(`posts/${id}`).get()).data();
        if(!post) { await ref.update({status:'deleted',workPending:false,leaseUntil:0});return; }
        const scores=await scan(photoPath(post,BUCKET)), decision=classify(scores);
        await ref.update({scores,status:decision==='clear'?'clear':'review', desiredHidden:decision==='hide',
          decision, updatedAt:stamp()});
        d=(await ref.get()).data();
      }
      const account=(await db.doc(`photo_moderation_accounts/${d.userId}`).get()).data();
      if(d.desiredHidden || ['closing','closed'].includes(account?.closureStatus)) await hide(id);
      else await restore(id);
      await db.runTransaction(async tx=>{
        const s=await tx.get(ref);if(s.data()?.lease!==lease) return;
        tx.update(ref,{workPending:false,leaseUntil:0,lastError:FieldValue.delete(),updatedAt:stamp()});
        if(d.desiredHidden) notify(tx,db,d.userId,`${id}_${d.status}`,'Fotoğrafın cinsel içerik/çıplaklık incelemesi nedeniyle gizlendi. Ayarlar → Paylaşım denetimi bölümünden itiraz edebilirsin.');
      });
    } catch(e) {
      // Failed analysis is never treated as a clean scan or a strike. Scheduler retries.
      await ref.update({leaseUntil:0,nextAttemptAt:Date.now()+300000,attempts:FieldValue.increment(1),lastError:String(e.message||'scan_failed').slice(0,100),updatedAt:stamp()});
      console.error('photo_moderation_retry',id,String(e.message||'failed').slice(0,100));
    } finally {
      await db.runTransaction(async tx=>{
        const ar=db.doc(`photo_moderation_accounts/${acquired}`), a=(await tx.get(ar)).data();
        if(a?.operationLease===lease) tx.update(ar,{operationUntil:0});
      });
    }
  }
  async function review(id, action, why, adminUid) {
    if(!['confirm','dismiss'].includes(action)) throw new HttpsError('invalid-argument','Geçersiz karar.');
    const ref=db.doc(`photo_moderation/${id}`);
    await db.runTransaction(async tx=>{
      const snap=await tx.get(ref), d=snap.data();
      if(!d || !['review','confirmed','dismissed'].includes(d.status)) throw new HttpsError('failed-precondition','Önce denetimin tamamlanması gerekiyor.');
      if(d.leaseUntil>Date.now()) throw new HttpsError('aborted','Fotoğraf işleniyor, birazdan tekrar dene.');
      const ar=db.doc(`photo_moderation_accounts/${d.userId}`), as=await tx.get(ar), a=as.data()||{};
      if(['closing','reopening'].includes(a.closureStatus)) throw new HttpsError('aborted','Hesap işlemi tamamlanınca tekrar dene.');
      const next=action==='confirm'?'confirmed':'dismissed', delta=strikeChange(d.status,next), count=Math.max(0,(a.strikes||0)+delta);
      const closure=closureStatus(count,a.closureStatus,delta);
      tx.update(ref,{status:next,desiredHidden:next==='confirmed',workPending:true,reviewedBy:adminUid,decisionReason:why,
        appealStatus:d.appealStatus==='pending'?(action==='dismiss'?'accepted':'rejected'):(d.appealStatus||'none'),updatedAt:stamp()});
      tx.set(ar,{userId:d.userId,strikes:count,closureStatus:closure,updatedAt:stamp()},{merge:true});
      tx.create(db.collection('admin_audit_logs').doc(),{adminUid,action:`photo_${action}`,postId:id,userId:d.userId,reason:why,delta,createdAt:stamp()});
      notify(tx,db,d.userId,`${id}_decision`, action==='confirm'?`İhlal doğrulandı. Doğrulanmış paylaşım sayısı: ${count}. İtiraz edebilirsin.`:'İnceleme sonucunda ihlal kaldırıldı; paylaşımın hesabın açıksa geri getirilecek.');
    });
    await process(id);
  }
  async function decideAccount(uid, action, why, adminUid) {
    const target=await auth.getUser(uid);
    if(target.customClaims?.admin || uid===adminUid) throw new HttpsError('permission-denied','Yönetici hesabı kapatılamaz.');
    if(!['approve','reject','reopen'].includes(action)) throw new HttpsError('invalid-argument','Geçersiz karar.');
    const ref=db.doc(`photo_moderation_accounts/${uid}`), appealCode=randomUUID()+randomUUID();
    await db.runTransaction(async tx=>{
      const s=await tx.get(ref), a=s.data();
      if(!a) throw new HttpsError('not-found','Hesap incelemesi bulunamadı.');
      if(a.operationUntil>Date.now()) throw new HttpsError('aborted','Hesabın fotoğraf işlemi sürüyor, birazdan tekrar dene.');
      if(action==='reopen') { if(a.closureStatus!=='closed') throw new HttpsError('failed-precondition','Hesap kapalı değil.'); }
      else if(a.closureStatus!=='pending'||a.strikes<5) throw new HttpsError('failed-precondition','Beş doğrulanmış ihlal ve bekleyen inceleme gerekli.');
      tx.update(ref,{closureStatus:action==='approve'?'closing':action==='reopen'?'reopening':'rejected',decisionReason:why,reviewedBy:adminUid,updatedAt:stamp(),
        ...(action==='approve'?{appealCode}:{}),...(action==='reopen'?{appealStatus:'accepted',reopenCursor:FieldValue.delete()}:{})});
      if(action==='approve') {
        tx.set(db.doc(`photo_moderation_appeal_keys/${hash(appealCode)}`),{userId:uid,used:false});
        notify(tx,db,uid,'account_closed',`Hesabın admin kararıyla kapatılıyor: ${why}. Giriş ekranındaki Hesap itirazı için kodun: ${appealCode}`);
        tx.set(db.doc(`users/${uid}`),{banned:true,disabled:true},{merge:true});
      }
      tx.create(db.collection('admin_audit_logs').doc(),{adminUid,action:`photo_account_${action}`,userId:uid,reason:why,createdAt:stamp()});
    });
    if(action!=='reject') await processAccount(uid);
  }
  async function processAccount(uid) {
    const ref=db.doc(`photo_moderation_accounts/${uid}`);
    const state=await db.runTransaction(async tx=>{
      const a=(await tx.get(ref)).data();
      if(!a || !['closing','reopening'].includes(a.closureStatus)||a.leaseUntil>Date.now()||a.operationUntil>Date.now()) return null;
      tx.update(ref,{leaseUntil:Date.now()+360000}); return a.closureStatus;
    });
    if(!state) return;
    try {
      if(state==='closing') {
        await auth.updateUser(uid,{disabled:true});await auth.revokeRefreshTokens(uid);
        // Page without a cursor: each processed post is removed from the public collection.
        const posts=await db.collection('posts').where('userId','==',uid).limit(100).get();
        for(const p of posts.docs) await hide(p.id);
        if(posts.size===100) {await ref.update({leaseUntil:0});return;}
        await ref.update({closureStatus:'closed',leaseUntil:0,closedAt:stamp()});
      } else {
        // Do not resurrect confirmed violations. Only restore posts hidden by account closure.
        const cursor=(await ref.get()).data().reopenCursor;
        let query=db.collection('photo_moderation_archive').where('post.userId','==',uid).orderBy('__name__');
        if(cursor) query=query.startAfter(cursor);
        const archives=await query.limit(50).get();
        for(const s of archives.docs) {
          const c=(await db.doc(`photo_moderation/${s.id}`).get()).data();
          if(!c?.desiredHidden) await restore(s.id);
        }
        if(archives.size===50) {await ref.update({leaseUntil:0,reopenCursor:archives.docs.at(-1).id});return;}
        await auth.updateUser(uid,{disabled:false});
        await db.doc(`users/${uid}`).set({banned:false,disabled:false},{merge:true});
        await ref.update({closureStatus:'rejected',leaseUntil:0,reopenedAt:stamp()});
      }
    } catch(e) { await ref.update({leaseUntil:0,lastError:String(e.message).slice(0,100)}); throw e; }
  }
  return {enqueue,process,review,decideAccount,processAccount,hide,restore};
}
exports.moderatePhotoPost=onDocumentCreated({...opts,document:'posts/{postId}',retry:true},async e=>{
  const engine=createEngine(),post=e.data?.data();
  if(post?.userId) {
    const a=(await getFirestore().doc(`photo_moderation_accounts/${post.userId}`).get()).data();
    if(['closing','closed'].includes(a?.closureStatus)) { await engine.hide(e.params.postId);return; }
  }
  await engine.enqueue(e.params.postId,post);
});
exports.processPhotoModeration=onDocumentWritten({...opts,document:'photo_moderation/{postId}',retry:true},async e=>{
  if(e.data?.after.data()?.workPending) await createEngine().process(e.params.postId);
});
exports.retryPhotoModeration=onSchedule({...opts,schedule:'every 5 minutes'},async()=>{
  const db=getFirestore(),engine=createEngine();
  // Oldest failures first, with a capped batch to keep runtime and API cost bounded.
  const jobs=await db.collection('photo_moderation').where('workPending','==',true).orderBy('updatedAt').limit(40).get();
  for(const d of jobs.docs) await engine.process(d.id);
  for(const status of ['closing','reopening']) {
    const accounts=await db.collection('photo_moderation_accounts').where('closureStatus','==',status).limit(10).get();
    for(const d of accounts.docs) await engine.processAccount(d.id);
  }
});
exports.reviewPhotoModeration=onCall(opts,async r=>{const uid=admin(r);await createEngine().review(validId(r.data?.id),r.data?.action,reason(r.data?.reason),uid);return {ok:true};});
exports.reviewPhotoAccount=onCall(opts,async r=>{const uid=admin(r);await createEngine().decideAccount(validId(r.data?.uid),r.data?.action,reason(r.data?.reason),uid);return {ok:true};});
exports.appealPhotoModeration=onCall(opts,async r=>{
  if(!r.auth) throw new HttpsError('unauthenticated','Giriş yapmalısın.');
  const id=validId(r.data?.id), why=reason(r.data?.reason), db=getFirestore(),ref=db.doc(`photo_moderation/${id}`);
  await db.runTransaction(async tx=>{
    const d=(await tx.get(ref)).data();
    if(d?.userId!==r.auth.uid) throw new HttpsError('permission-denied','Bu paylaşım sana ait değil.');
    if(!['review','confirmed'].includes(d.status)||['pending','accepted','rejected'].includes(d.appealStatus)) throw new HttpsError('failed-precondition','Bu karara itiraz zaten alındı veya inceleme tamamlandı.');
    tx.update(ref,{appealStatus:'pending',appealReason:why,appealedAt:stamp(),updatedAt:stamp()});
  });return {ok:true};
});
exports.appealClosedPhotoAccount=onCall({...opts,maxInstances:2},async r=>{
  const code=String(r.data?.code||'').trim();if(!/^[a-f0-9-]{72}$/.test(code)) throw new HttpsError('invalid-argument','Bildirimdeki itiraz kodunu eksiksiz gir.');
  const db=getFirestore(),key=db.doc(`photo_moderation_appeal_keys/${hash(code)}`),why=reason(r.data?.reason);
  await db.runTransaction(async tx=>{
    const k=(await tx.get(key)).data();if(!k||k.used) throw new HttpsError('permission-denied','Kod geçersiz veya kullanılmış.');
    tx.update(key,{used:true});tx.update(db.doc(`photo_moderation_accounts/${k.userId}`),{appealStatus:'pending',appealReason:why,updatedAt:stamp()});
  });return {ok:true};
});
exports.photoModerationPreview=onCall(opts,async r=>{
  admin(r);const id=validId(r.data?.id), db=getFirestore();
  const d=(await db.doc(`photo_moderation/${id}`).get()).data();
  if(!d || !ownedPaths(d).includes(d.storagePath)) throw new HttpsError('not-found','Fotoğraf bulunamadı.');
  const file=getStorage().bucket(BUCKET).file(d.storagePath), [metadata]=await file.getMetadata();
  if(Number(metadata.size)>15*1024*1024) throw new HttpsError('resource-exhausted','Önizleme boyut sınırını aşıyor.');
  const [bytes]=await file.download();return {base64:bytes.toString('base64')};
});
// Non-function export for emulator tests; bootstrap only exports the named handlers below.
exports.createEngine=createEngine;
