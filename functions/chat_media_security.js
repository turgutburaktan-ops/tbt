const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const BUCKET = 'en-iyi-cekim-noktasi.firebasestorage.app';
const key = s => {
  if (typeof s !== 'string' || !/^[A-Za-z0-9_-]{1,160}$/.test(s))
    throw new HttpsError('invalid-argument','Geçersiz medya kimliği.');
  return s;
};
async function sealFile(file) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const [meta] = await file.getMetadata();
    try {
      await file.setMetadata({cacheControl:'private, no-store, max-age=0',
        metadata:{...meta.metadata, firebaseStorageDownloadTokens:null, chatSealed:'true'}},
        {ifMetagenerationMatch:meta.metageneration});
      const [verified] = await file.getMetadata();
      if (verified.metadata?.firebaseStorageDownloadTokens)
        throw Error('Medya bağlantısı güvenli şekilde kapatılamadı.');
      return;
    } catch (error) {
      if (Number(error.code) !== 412 || attempt === 2) throw error;
    }
  }
}
async function finalizeChatMediaHandler(request, db = getFirestore(), bucket = getStorage().bucket(BUCKET)) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated','Giriş yapmalısın.');
  const d=request.data||{}, threadId=key(d.threadId), messageId=key(d.messageId);
  if (!['media.jpg','media.png','media.webp','audio.m4a'].includes(d.fileName))
    throw new HttpsError('invalid-argument','Geçersiz dosya.');
  const thread=(await db.doc(`chat_threads/${threadId}`).get()).data();
  if (!thread?.memberIds?.includes(uid))
    throw new HttpsError('permission-denied','Bu sohbete erişimin yok.');
  const path=`private_chat/${threadId}/${uid}/${messageId}/${d.fileName}`;
  const file=bucket.file(path);
  await sealFile(file);
  return {storageUrl:`gs://${BUCKET}/${path}`};
}
exports.finalizeChatMedia=onCall({region:'europe-west1',maxInstances:10},
  request=>finalizeChatMediaHandler(request));
// The callable seals every normal app upload before its message is created.
// A bounded sweep also removes tokens from abandoned/custom-client uploads.
const privateNamespaces = ['private_chat/', 'route_albums/', 'route_chat/', 'event_chat/', 'users/'];
function privatePath(path) {
  return /^(private_chat|route_albums|route_chat|event_chat)\/[^/]+\/[^/]+\/[^/]+\/[^/]+$/.test(path) ||
    /^users\/[^/]+\/chat\/[^/]+\/[^/]+$/.test(path) ||
    /^users\/[^/]+\/business_claims\/[^/]+\/evidence\.(jpg|png|webp)$/.test(path);
}
async function finalizePrivateMediaHandler(request, db = getFirestore(), bucket = getStorage().bucket(BUCKET)) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  const path = request.data?.storagePath;
  if (typeof path !== 'string' || path.length > 700 || !privatePath(path))
    throw new HttpsError('invalid-argument', 'Geçersiz medya yolu.');
  const [namespace, parent, owner] = path.split('/');
  if (!['route_albums', 'route_chat', 'event_chat'].includes(namespace) || owner !== uid)
    throw new HttpsError('permission-denied', 'Dosyanın sahibi değilsin.');
  const collection = namespace === 'event_chat' ? 'social_events' : 'travel_plans';
  const doc = (await db.doc(`${collection}/${parent}`).get()).data();
  const allowed = namespace === 'event_chat' ? doc?.hostId === uid || doc?.participantIds?.includes(uid) : doc?.memberIds?.includes(uid);
  if (!allowed) throw new HttpsError('permission-denied', 'Bu medyaya erişimin yok.');
  await sealFile(bucket.file(path));
  return {ok: true};
}
exports.finalizePrivateMedia = onCall({region:'europe-west1',maxInstances:10}, request=>finalizePrivateMediaHandler(request));
async function sealPendingChatMediaHandler(db = getFirestore(), bucket = getStorage().bucket(BUCKET)) {
  for (const prefix of privateNamespaces) {
    const state = db.doc('maintenance_jobs/' + (prefix === 'private_chat/' ? 'chat_media_seal' : prefix.slice(0,-1) + '_media_seal'));
    const prior = (await state.get()).data() || {};
    const query = {prefix,maxResults:100,autoPaginate:false};
    if (prior.pageToken) query.pageToken = prior.pageToken;
    let result;
    try { result = await bucket.getFiles(query); }
    catch (error) {
      if (Number(error.code) !== 400 || !query.pageToken) throw error;
      delete query.pageToken; result = await bucket.getFiles(query);
    }
    const [files,next] = result;
    for (let offset=0;offset<files.length;offset+=10) {
      await Promise.all(files.slice(offset,offset+10).map(async file=>{
        if (!privatePath(file.name)) return;
        const meta=file.metadata?.metadata;
        if (meta?.chatSealed==='true' && !meta.firebaseStorageDownloadTokens) return;
        try { await sealFile(file); } catch(error) { if(Number(error.code)!==404) throw error; }
      }));
    }
    await state.set({pageToken:next?.pageToken||null,updatedAt:Date.now()});
  }
}
exports._finalizePrivateMediaHandler = finalizePrivateMediaHandler;
exports._privatePath = privatePath;
exports.sealPendingChatMedia=onSchedule({schedule:'every 5 minutes',region:'europe-west1',
  maxInstances:1,concurrency:1,timeoutSeconds:240},()=>sealPendingChatMediaHandler());
exports._sealPendingChatMediaHandler=sealPendingChatMediaHandler;
exports._finalizeChatMediaHandler=finalizeChatMediaHandler;
exports._sealChatFile=sealFile;
