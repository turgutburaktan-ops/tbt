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
async function sealPendingChatMediaHandler(db = getFirestore(), bucket = getStorage().bucket(BUCKET)) {
  const state = db.doc('maintenance_jobs/chat_media_seal');
  const prior = (await state.get()).data() || {};
  const query = {prefix:'private_chat/',maxResults:100,autoPaginate:false};
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
      if (!/^private_chat\/[^/]+\/[^/]+\/[^/]+\/(media\.(jpg|png|webp)|audio\.m4a)$/.test(file.name)) return;
      const meta=file.metadata?.metadata;
      if (meta?.chatSealed==='true' && !meta.firebaseStorageDownloadTokens) return;
      try { await sealFile(file); } catch(error) { if(Number(error.code)!==404) throw error; }
    }));
  }
  await state.set({pageToken:next?.pageToken||null,updatedAt:Date.now()});
}
exports.sealPendingChatMedia=onSchedule({schedule:'every 5 minutes',region:'europe-west1',
  maxInstances:1,concurrency:1,timeoutSeconds:240},()=>sealPendingChatMediaHandler());
exports._sealPendingChatMediaHandler=sealPendingChatMediaHandler;
exports._finalizeChatMediaHandler=finalizeChatMediaHandler;
exports._sealChatFile=sealFile;
