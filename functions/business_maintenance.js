const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

async function expireCollection(collectionId, dateField) {
  const db = getFirestore();
  const now = Timestamp.now();
  const snap = await db.collectionGroup(collectionId)
    .where('active', '==', true)
    .where(dateField, '<=', now)
    .limit(400)
    .get();
  if (snap.empty) return 0;
  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.update(doc.ref, {
      active: false,
      expiredAutomatically: true,
      expiredAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return snap.size;
}

exports.expireBusinessContent = onSchedule(
  {region: 'europe-west1', schedule: 'every 60 minutes', timeZone: 'Europe/Istanbul'},
  async () => {
    await Promise.all([
      expireCollection('campaigns', 'validUntil'),
      expireCollection('program', 'startsAt'),
    ]);
  }
);
