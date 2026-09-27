const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

async function expireCollection(collectionId, dateField) {
  const db = getFirestore();
  const now = Timestamp.now();
  const snap = await db.collectionGroup(collectionId)
    .where(dateField, '<=', now)
    .limit(400)
    .get();
  if (snap.empty) return 0;
  const activeDocs = snap.docs.filter((doc) => doc.data()?.active !== false);
  if (activeDocs.length === 0) return 0;
  const batch = db.batch();
  for (const doc of activeDocs) {
    batch.update(doc.ref, {
      active: false,
      expiredAutomatically: true,
      expiredAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return activeDocs.length;
}

async function expireBoosts() {
  const db = getFirestore();
  const now = Timestamp.now();
  const snap = await db.collectionGroup('boosts')
    .where('endsAt', '<=', now)
    .limit(300)
    .get();
  const expired = snap.docs.filter((doc) => (doc.data()?.status || '') !== 'expired');
  if (expired.length === 0) return 0;

  const parentRefs = new Map();
  for (const doc of expired) {
    const venueRef = doc.ref.parent.parent;
    if (venueRef) parentRefs.set(venueRef.path, venueRef);
  }
  const parentSnaps = await Promise.all([...parentRefs.values()].map((ref) => ref.get()));
  const clearable = new Set();
  for (const venueSnap of parentSnaps) {
    const until = venueSnap.data()?.boostActiveUntil;
    if (!(until instanceof Timestamp) || until.toMillis() <= now.toMillis()) {
      clearable.add(venueSnap.ref.path);
    }
  }

  const batch = db.batch();
  for (const doc of expired) {
    batch.update(doc.ref, {
      status: 'expired',
      expiredAt: FieldValue.serverTimestamp(),
    });
    const venueRef = doc.ref.parent.parent;
    if (venueRef && clearable.has(venueRef.path)) {
      batch.set(venueRef, {
        boostActive: false,
        boostActiveUntil: null,
        boostTargetType: null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }
  await batch.commit();
  return expired.length;
}

exports.expireBusinessContent = onSchedule(
  {region: 'europe-west1', schedule: 'every 60 minutes', timeZone: 'Europe/Istanbul'},
  async () => {
    await Promise.all([
      expireCollection('campaigns', 'validUntil'),
      expireCollection('program', 'startsAt'),
      expireBoosts(),
    ]);
  }
);
