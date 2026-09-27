const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {randomUUID, createHash} = require('node:crypto');
const fail = (code, message) => { throw new HttpsError(code, message); };
const key = value => {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,160}$/.test(value))
    fail('invalid-argument', 'Geçersiz kimlik.');
  return value;
};
const MAX_BYTES = 512 * 1024;
const SESSION_MS = 120000;

async function privatePhotoHandler(request, db = getFirestore(), now = Date.now()) {
  const uid = request.auth?.uid;
  if (!uid) fail('unauthenticated', 'Giriş yapmalısın.');
  const data = request.data || {};
  const threadId = key(data.threadId), messageId = key(data.messageId);
  if (!['send', 'open', 'close'].includes(data.action))
    fail('invalid-argument', 'Geçersiz işlem.');
  const threadRef = db.doc(`chat_threads/${threadId}`);
  const messageRef = threadRef.collection('messages').doc(messageId);
  // No client rules match this root collection: bytes and counters are server-only.
  const privateRef = db.doc(`chat_private_photos/${messageId}`);
  let encoded, hash;
  if (data.action === 'send') {
    if (!['once', 'replay'].includes(data.mode) || typeof data.bytes !== 'string' ||
        data.bytes.length > Math.ceil(MAX_BYTES / 3) * 4)
      fail('invalid-argument', 'Fotoğraf veya görüntüleme seçimi geçersiz.');
    const bytes = Buffer.from(data.bytes, 'base64');
    if (bytes.length < 4 || bytes.length > MAX_BYTES || bytes[0] !== 255 ||
        bytes[1] !== 216 || bytes[bytes.length - 2] !== 255 || bytes[bytes.length - 1] !== 217)
      fail('invalid-argument', 'Fotoğraf JPEG olarak hazırlanamadı.');
    encoded = bytes.toString('base64');
    hash = createHash('sha256').update(bytes).digest('hex');
  }
  return db.runTransaction(async tx => {
    const [threadSnap, messageSnap, privateSnap] = await Promise.all([
      tx.get(threadRef), tx.get(messageRef), tx.get(privateRef),
    ]);
    const thread = threadSnap.data(), message = messageSnap.data(), photo = privateSnap.data();
    if (!thread?.memberIds?.includes(uid))
      fail('permission-denied', 'Bu sohbete erişimin yok.');
    if (data.action === 'close') {
      if (photo?.threadId === threadId && photo.sessions?.[uid]?.token === data.session) {
        const sessions = {...photo.sessions}; delete sessions[uid];
        tx.update(privateRef, {sessions});
      }
      return {ok: true};
    }
    const peers = data.action === 'send' ? thread.memberIds.filter(id => id !== uid) : [photo?.senderId];
    if (!peers.length || peers.length > 49 || peers.some(id => !id))
      fail('failed-precondition', 'Fotoğraf artık açılamıyor.');
    const blocks = await Promise.all(peers.flatMap(other => [
      tx.get(db.doc(`users/${uid}/blocked/${other}`)),
      tx.get(db.doc(`users/${other}/blocked/${uid}`)),
    ]));
    if (blocks.some(s => s.exists))
      fail('permission-denied', 'Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    if (thread.type === 'direct' && thread.requestStatus && thread.requestStatus !== 'accepted')
      fail('failed-precondition', 'Önce mesaj isteği kabul edilmeli.');
    if (data.action === 'send') {
      if (messageSnap.exists || privateSnap.exists) {
        if (photo?.senderId === uid && photo.threadId === threadId && photo.hash === hash && photo.mode === data.mode)
          return {messageId};
        fail('already-exists', 'Bu mesaj kimliği zaten kullanıldı.');
      }
      const sender = (await tx.get(db.doc(`users/${uid}`))).data();
      const maxViews = data.mode === 'once' ? 1 : 2;
      const label = data.mode === 'once' ? '① Bir kez görüntülenebilen fotoğraf' : '② Tekrar açılabilen fotoğraf';
      tx.create(privateRef, {threadId, senderId: uid, recipients: peers,
        bytes: encoded, hash, mode: data.mode, maxViews, views: {}, sessions: {},
        expiresAt: Timestamp.fromMillis(now + 7 * 86400000)});
      tx.create(messageRef, {senderId: uid, senderName: sender?.displayName || sender?.name || 'Üye',
        type: 'private_photo', photoMode: data.mode, photoViews: {}, text: label,
        mediaUrl: null, deleted: false, createdAt: FieldValue.serverTimestamp()});
      tx.update(threadRef, {lastMessageId: messageId, lastMessage: label, lastSenderId: uid,
        lastMessageAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
      if (thread.type === 'direct') {
        tx.create(db.doc(`users/${peers[0]}/notifications/chat_${messageId}`),
          {type: 'message', sourceId: threadId, actorId: uid, title: 'Yeni fotoğraf',
            body: label, read: false, createdAt: FieldValue.serverTimestamp()});
      }
      return {messageId};
    }
    if (!photo || photo.threadId !== threadId || !photo.recipients.includes(uid) ||
        photo.senderId === uid || message?.type !== 'private_photo' || message.deleted ||
        thread.deletedMessageIds?.includes(messageId) || photo.expiresAt.toMillis() <= now)
      fail('permission-denied', 'Bu fotoğraf artık açılamıyor.');
    const used = photo.views[uid] || 0;
    if (used >= photo.maxViews || !photo.bytes)
      fail('failed-precondition', 'Görüntüleme hakkın bitti.');
    if (photo.sessions?.[uid]?.until > now)
      fail('failed-precondition', 'Fotoğraf başka bir ekranda açık. Kapatıp tekrar dene.');
    const session = randomUUID();
    const views = {...photo.views, [uid]: used + 1};
    const sessions = {...photo.sessions, [uid]: {token: session, until: now + SESSION_MS}};
    const exhausted = photo.recipients.every(id => (views[id] || 0) >= photo.maxViews);
    tx.update(privateRef, {views, sessions, ...(exhausted ? {bytes: FieldValue.delete()} : {})});
    tx.update(messageRef, {photoViews: views});
    // The transaction consumes the right before returning bytes, also across devices.
    return {bytes: photo.bytes, session, remaining: photo.maxViews - used - 1, sessionMs: SESSION_MS};
  });
}

exports.chatPrivatePhoto = onCall({region: 'europe-west1', timeoutSeconds: 30, memory: '256MiB', maxInstances: 10}, request => privatePhotoHandler(request));
exports.expireChatPrivatePhotos = onSchedule({schedule: 'every 60 minutes', region: 'europe-west1'}, async () => {
  const db = getFirestore();
  for (let page = 0; page < 10; page++) {
    const snapshots = await db.collection('chat_private_photos').where('expiresAt', '<=', Timestamp.now()).limit(100).get();
    if (snapshots.empty) break;
    const batch = db.batch(); snapshots.docs.forEach(doc => batch.delete(doc.ref)); await batch.commit();
  }
});
exports._privatePhotoHandler = privatePhotoHandler;
