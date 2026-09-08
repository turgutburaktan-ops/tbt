const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {randomBytes} = require('node:crypto');
const fail = (message) => { throw new HttpsError('failed-precondition', message); };
const text = (v, max = 1500) => {
  if (typeof v !== 'string' || !v.trim() || v.trim().length > max) fail('Geçersiz veya çok uzun metin.');
  return v.trim();
};
const id = v => { const s = text(v, 128); if (s.includes('/')) fail('Geçersiz kimlik.'); return s; };

// All membership and message-management changes run in transactions on the server.
// Clients cannot promote themselves, forge reactions, or delete another sender's text.
async function chatActionHandler(request, db = getFirestore()) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Giriş yapmalısın.');
  const d = request.data || {}, action = d.action;
  if (action === 'create') {
    const ref = db.collection('chat_threads').doc();
    await ref.set({type: 'group', name: text(d.name, 80), ownerId: uid, adminIds: [uid], memberIds: [uid], createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), lastMessage: 'Grup oluşturuldu', lastMessageAt: FieldValue.serverTimestamp()});
    return {threadId: ref.id};
  }
  if (action === 'join') {
    const code = id(d.code), inviteRef = db.collection('chat_invites').doc(code);
    return db.runTransaction(async tx => {
      const inv = (await tx.get(inviteRef)).data();
      if (!inv || inv.expiresAt.toMillis() < Date.now()) fail('Davet geçersiz veya süresi dolmuş.');
      const ref = db.collection('chat_threads').doc(inv.threadId), t = (await tx.get(ref)).data();
      if (!t || t.inviteCode !== code || t.type !== 'group') fail('Davet iptal edilmiş.');
      if (t.memberIds.includes(uid)) return {threadId: ref.id};
      if (t.memberIds.length >= 50) fail('Grup en fazla 50 kişi olabilir.');
      if (t.removedIds?.includes(uid)) fail('Gruptan çıkarıldın; yönetici yeniden davet etmelidir.');
      const blocks = await Promise.all([tx.get(db.doc(`users/${uid}/blocked/${t.ownerId}`)), tx.get(db.doc(`users/${t.ownerId}/blocked/${uid}`))]);
      if (blocks.some(s => s.exists)) fail('Bu gruba katılım kullanılamıyor.');
      tx.update(ref, {memberIds: [...t.memberIds, uid], updatedAt: FieldValue.serverTimestamp()});
      return {threadId: ref.id};
    });
  }
  const threadId = id(d.threadId), ref = db.collection('chat_threads').doc(threadId);
  return db.runTransaction(async tx => {
    const t = (await tx.get(ref)).data();
    if (!t || !t.memberIds.includes(uid)) throw new HttpsError('permission-denied', 'Bu sohbete erişimin yok.');
    const admin = t.type === 'group' && t.adminIds.includes(uid);
    const requireAdmin = () => { if (!admin) throw new HttpsError('permission-denied', 'Yönetici yetkisi gerekli.'); };
    if (t.type === 'direct' && !['preferences','hide','accept'].includes(action)) {
      const other = t.memberIds.find(x => x !== uid);
      const blocks = await Promise.all([tx.get(db.doc(`users/${uid}/blocked/${other}`)), tx.get(db.doc(`users/${other}/blocked/${uid}`))]);
      if (blocks.some(s => s.exists)) fail('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    if (action === 'preferences') {
      if (typeof d.muted !== 'boolean' || typeof d.readReceipts !== 'boolean') fail('Geçersiz tercih.');
      tx.set(db.doc(`users/${uid}/chat_preferences/${threadId}`), {muted: d.muted, readReceipts: d.readReceipts}, {merge: true});
      if (!d.readReceipts) tx.update(ref, {[`lastReadAt.${uid}`]: FieldValue.delete()});
    } else if (action === 'hide') {
      tx.set(db.doc(`users/${uid}/chat_preferences/${threadId}/hidden/${id(d.messageId)}`), {hidden: true});
    } else if (action === 'rename') {
      requireAdmin(); tx.update(ref, {name: text(d.name, 80)});
    } else if (action === 'photo') {
      requireAdmin(); const url = text(d.photoUrl, 2000);
      if (!url.startsWith('https://firebasestorage.googleapis.com/')) fail('Geçersiz fotoğraf.');
      tx.update(ref, {photoUrl: url});
    } else if (action === 'invite') {
      requireAdmin();
      const code = randomBytes(24).toString('hex');
      tx.set(db.collection('chat_invites').doc(code), {threadId, expiresAt: Timestamp.fromMillis(Date.now() + 7 * 86400000)});
      tx.update(ref, {inviteCode: code});
      return {code};
    } else if (action === 'remove' || action === 'leave') {
      if (t.type !== 'group') fail('Bu işlem gruplar içindir.');
      const target = action === 'leave' ? uid : id(d.userId);
      if (target !== uid) requireAdmin();
      if (target === t.ownerId && t.memberIds.length > 1) fail('Önce grup sahipliğini başka bir üyeye devret.');
      tx.update(ref, {memberIds: t.memberIds.filter(x => x !== target), adminIds: t.adminIds.filter(x => x !== target), ...(t.memberIds.length === 1 ? {inviteCode: FieldValue.delete()} : {}), ...(action === 'remove' ? {removedIds: FieldValue.arrayUnion(target)} : {})});
    } else if (action === 'admin' || action === 'transfer' || action === 'allowRejoin') {
      if (t.ownerId !== uid) fail('Yalnızca grup sahibi yapabilir.');
      const target = id(d.userId);
      if (action === 'allowRejoin') tx.update(ref, {removedIds: FieldValue.arrayRemove(target)});
      else {
        if (!t.memberIds.includes(target)) fail('Üye bulunamadı.');
        tx.update(ref, {adminIds: FieldValue.arrayUnion(target), ...(action === 'transfer' ? {ownerId: target} : {})});
      }
    } else if (action === 'poll') {
      if (t.type !== 'group') fail('Anket grup sohbeti içindir.');
      const options = Array.isArray(d.options) ? d.options.map(v => text(v, 120)) : [];
      if (options.length < 2 || options.length > 6 || new Set(options).size !== options.length) fail('2–6 farklı seçenek yaz.');
      const msg = ref.collection('messages').doc();
      tx.set(msg, {senderId: uid, senderName: text(request.auth.token?.name || 'Üye', 120), type: 'poll', text: text(d.question, 200), options, votes: {}, closed: false, deleted: false, createdAt: FieldValue.serverTimestamp()});
      tx.update(ref, {lastMessageId: msg.id, lastMessage: `Anket: ${d.question}`, lastSenderId: uid, lastMessageAt: FieldValue.serverTimestamp()});
    } else {
      const msgRef = ref.collection('messages').doc(id(d.messageId)), m = (await tx.get(msgRef)).data();
      if (!m) fail('Mesaj bulunamadı.');
      if (action === 'pin') {
        if (t.type === 'group') requireAdmin();
        if (m.deleted) fail('Silinmiş mesaj sabitlenemez.');
        tx.update(ref, {pinnedMessageId: t.pinnedMessageId === msgRef.id ? FieldValue.delete() : msgRef.id});
      } else if (action === 'reaction') {
        const emoji = text(d.emoji, 8);
        if (!['❤️','😂','🔥','👏','👍','😮'].includes(emoji) || m.deleted) fail('Geçersiz tepki.');
        const reactions = {...(t.messageReactions?.[msgRef.id] || {}), ...(m.reactions || {})};
        if (reactions[uid] === emoji) delete reactions[uid]; else reactions[uid] = emoji;
        tx.update(msgRef, {reactions});
        if (t.messageReactions?.[msgRef.id]) tx.update(ref, {[`messageReactions.${msgRef.id}`]: FieldValue.delete()});
      } else if (action === 'edit' || action === 'delete') {
        if (m.senderId !== uid) fail('Yalnızca kendi mesajını değiştirebilirsin.');
        if (action === 'edit') {
          if (m.type !== 'text' || m.deleted || Date.now() - m.createdAt.toMillis() > 15 * 60000) fail('Metin mesajları ilk 15 dakika içinde düzenlenebilir.');
          tx.update(msgRef, {text: text(d.text), editedAt: FieldValue.serverTimestamp()});
          if (t.lastMessageId === msgRef.id) tx.update(ref, {lastMessage: text(d.text)});
        } else {
          tx.update(msgRef, {text: 'Mesaj geri alındı', deleted: true, mediaUrl: null, replyText: null, sharedTitle: null, sharedImageUrl: null, options: [], votes: {}, reactions: {}, deletedAt: FieldValue.serverTimestamp()});
          if (t.lastMessageId === msgRef.id || (t.lastSenderId === uid && t.lastMessage === m.text)) tx.update(ref, {lastMessage: 'Mesaj geri alındı'});
          if (t.pinnedMessageId === msgRef.id) tx.update(ref, {pinnedMessageId: FieldValue.delete()});
        }
      } else if (action === 'vote' || action === 'closePoll') {
        if (m.type !== 'poll' || m.deleted) fail('Anket bulunamadı.');
        if (action === 'closePoll') {
          if (m.senderId !== uid && !admin) fail('Anketi oluşturan veya yönetici kapatabilir.');
          tx.update(msgRef, {closed: true});
        } else {
          if (m.closed || !Number.isInteger(d.option) || d.option < 0 || d.option >= m.options.length) fail('Bu ankete oy verilemiyor.');
          tx.update(msgRef, {[`votes.${uid}`]: d.option});
        }
      } else throw new HttpsError('invalid-argument', 'Bilinmeyen işlem.');
    }
    return {ok: true};
  });
}
exports.chatAction = onCall({region: 'us-central1', maxInstances: 10}, request => chatActionHandler(request));
exports.chatGroupMessageNotification = onDocumentCreated('chat_threads/{threadId}/messages/{messageId}', async event => {
  const m = event.data?.data(); if (!m) return;
  const db = getFirestore(), ref = db.doc(`chat_threads/${event.params.threadId}`), t = (await ref.get()).data();
  if (t?.type !== 'group' || !t.memberIds.includes(m.senderId)) return;
  await Promise.all(t.memberIds.filter(uid => uid !== m.senderId).map(async uid => {
    const [prefs, blocked] = await Promise.all([db.doc(`users/${uid}/chat_preferences/${ref.id}`).get(), db.doc(`users/${uid}/blocked/${m.senderId}`).get()]);
    if (prefs.data()?.muted || blocked.exists) return;
    const n = db.doc(`users/${uid}/notifications/chat_${event.params.messageId}`);
    await n.set({type: 'group_message', sourceId: ref.id, actorId: m.senderId, title: t.name, body: String(m.text).slice(0, 150), read: false, createdAt: m.createdAt});
  }));
});
exports._chatActionHandler = chatActionHandler;
