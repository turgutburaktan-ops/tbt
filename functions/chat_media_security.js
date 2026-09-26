const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onObjectFinalized} = require('firebase-functions/v2/storage');
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
exports.sealUploadedChatMedia=onObjectFinalized({bucket:BUCKET,region:'europe-west1',maxInstances:10},
  async event=>{
    const name=event.data.name||'';
    if (!/^private_chat\/[^/]+\/[^/]+\/[^/]+\/(media\.(jpg|png|webp)|audio\.m4a)$/.test(name)) return;
    await sealFile(getStorage().bucket(BUCKET).file(name));
  });
exports._finalizeChatMediaHandler=finalizeChatMediaHandler;
exports._sealChatFile=sealFile;
