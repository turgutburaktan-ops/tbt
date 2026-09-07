const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldPath, FieldValue} = require('firebase-admin/firestore');
const {marketingPushAllowed} = require('./broadcast_policy');

// Cursor and inbox writes commit together. Retries never create duplicate inbox
// entries or reprocess committed pages, even when workers overlap.
exports.deliverAdminBroadcast = onDocumentCreated({
  document: 'admin_broadcasts/{broadcastId}', region: 'europe-west1',
  timeoutSeconds: 540, retry: true,
}, async event => {
  if (!event.data) return;
  const db = getFirestore(), ref = event.data.ref;
  for (let page = 0; page < 100; page++) {
    const done = await db.runTransaction(async tx => {
      const current = await tx.get(ref), job = current.data();
      if (!job || job.status === 'completed') return true;
      if (!['queued', 'sending'].includes(job.status)) return true;
      let query = db.collection('users').orderBy(FieldPath.documentId()).limit(200);
      if (job.cursor) query = query.startAfter(job.cursor);
      const users = await tx.get(query);
      for (const user of users.docs) {
        tx.create(user.ref.collection('notifications').doc(`broadcast_${ref.id}`), {
          type: 'tbt_broadcast', title: job.title, body: job.body,
          sourceId: ref.id, actorId: job.sentBy, senderName: 'TBT',
          pushAllowed: marketingPushAllowed(user.data()),
          read: false, createdAt: FieldValue.serverTimestamp(),
        });
      }
      const completed = users.size < 200;
      tx.update(ref, {status: completed ? 'completed' : 'sending',
        recipientCount: (job.recipientCount || 0) + users.size,
        cursor: users.docs.at(-1)?.id || job.cursor,
        updatedAt: FieldValue.serverTimestamp(),
        ...(completed ? {completedAt: FieldValue.serverTimestamp()} : {}),
      });
      return completed;
    });
    if (done) return;
  }
  // Bound each invocation. Eventarc retries resume from the durable cursor.
  throw new Error('Broadcast has more pages; resume delivery.');
});
