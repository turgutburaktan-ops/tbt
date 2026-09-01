const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

function clean(value, max = 500) { return String(value || '').trim().slice(0, max); }
function venueKey(category, venueId) { return `${clean(category, 40)}:${clean(venueId, 180)}`; }
function requireAuth(request) { if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.'); return request.auth.uid; }

async function ownerContext(request, category, venueId) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const id = venueKey(category, venueId);
  const snap = await db.collection('business_claims').doc(id).get();
  const data = snap.data() || {};
  if (data.status !== 'verified' || data.applicantUid !== uid) throw new HttpsError('permission-denied', 'Yalnız doğrulanmış işletme sahibi bu işlemi yapabilir.');
  return {uid, db, id};
}

function configFor(type) {
  if (type === 'menu') return {collection: 'menu'};
  if (type === 'campaign') return {collection: 'campaigns'};
  if (type === 'program') return {collection: 'program'};
  throw new HttpsError('invalid-argument', 'Geçersiz içerik türü.');
}

async function verifyMenuImage(uid, venueKeyValue, itemId, storagePath) {
  const expected = `users/${uid}/business_menu/${venueKeyValue}/${itemId}/product.jpg`;
  if (storagePath !== expected) throw new HttpsError('permission-denied', 'Ürün görseli bu işletme ve ürünle eşleşmiyor.');
  const file = getStorage().bucket().file(expected);
  const [exists] = await file.exists();
  if (!exists) throw new HttpsError('failed-precondition', 'Ürün görseli Storage üzerinde bulunamadı.');
  const [meta] = await file.getMetadata();
  const size = Number(meta.size || 0);
  const type = String(meta.contentType || '').toLowerCase();
  if (size <= 0 || size > 10 * 1024 * 1024 || !['image/jpeg','image/png','image/webp'].includes(type)) {
    throw new HttpsError('invalid-argument', 'Ürün görseli türü veya boyutu geçersiz.');
  }
}

exports.updateBusinessContentItem = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await ownerContext(request, d.category, d.venueId);
  const type = clean(d.type, 20);
  const itemId = clean(d.itemId, 180);
  const cfg = configFor(type);
  if (!itemId) throw new HttpsError('invalid-argument', 'İçerik kimliği eksik.');
  const ref = db.collection('business_venues').doc(id).collection(cfg.collection).doc(itemId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'İçerik bulunamadı.');

  const update = {updatedAt: FieldValue.serverTimestamp(), updatedBy: uid};
  if (typeof d.active === 'boolean') update.active = d.active;

  if (type === 'menu') {
    if (d.name !== undefined) update.name = clean(d.name, 120);
    if (d.section !== undefined) update.section = clean(d.section, 80);
    if (d.description !== undefined) update.description = clean(d.description, 500);
    if (typeof d.available === 'boolean') update.available = d.available;
    if (d.priceMinor !== undefined) {
      const price = Number(d.priceMinor);
      if (!Number.isInteger(price) || price < 0 || price > 100000000) throw new HttpsError('invalid-argument', 'Fiyat bilgisi geçersiz.');
      update.priceMinor = price;
    }
    if (d.imageUrl !== undefined || d.imageStoragePath !== undefined) {
      const imageUrl = clean(d.imageUrl, 1200);
      const imageStoragePath = clean(d.imageStoragePath, 600);
      if (imageUrl || imageStoragePath) {
        await verifyMenuImage(uid, id, itemId, imageStoragePath);
        update.imageUrl = imageUrl;
        update.imageStoragePath = imageStoragePath;
      } else {
        update.imageUrl = '';
        update.imageStoragePath = '';
      }
    }
    const nextName = update.name ?? snap.data().name;
    const nextSection = update.section ?? snap.data().section;
    if (!nextName || !nextSection) throw new HttpsError('invalid-argument', 'Ürün adı ve bölüm zorunlu.');
  }

  if (type === 'campaign') {
    if (d.title !== undefined) update.title = clean(d.title, 140);
    if (d.description !== undefined) update.description = clean(d.description, 700);
    if (d.validUntilMs !== undefined) {
      const ms = Number(d.validUntilMs);
      if (!Number.isFinite(ms)) throw new HttpsError('invalid-argument', 'Kampanya tarihi geçersiz.');
      update.validUntil = Timestamp.fromMillis(ms);
      if (ms <= Date.now()) update.active = false;
    }
    const nextTitle = update.title ?? snap.data().title;
    const nextDescription = update.description ?? snap.data().description;
    if (!nextTitle || !nextDescription) throw new HttpsError('invalid-argument', 'Kampanya başlığı ve açıklaması zorunlu.');
  }

  if (type === 'program') {
    if (d.title !== undefined) update.title = clean(d.title, 160);
    if (d.description !== undefined) update.description = clean(d.description, 700);
    if (d.startsAtMs !== undefined) {
      const ms = Number(d.startsAtMs);
      if (!Number.isFinite(ms)) throw new HttpsError('invalid-argument', 'Program tarihi geçersiz.');
      update.startsAt = Timestamp.fromMillis(ms);
    }
    const nextTitle = update.title ?? snap.data().title;
    if (!nextTitle) throw new HttpsError('invalid-argument', 'Program başlığı zorunlu.');
  }

  if (type === 'program' && snap.data()?.socialEventId) {
    const eventUpdate = {updatedAt: FieldValue.serverTimestamp()};
    if (update.title !== undefined) eventUpdate.title = update.title;
    if (update.description !== undefined) eventUpdate.description = update.description;
    if (update.startsAt !== undefined) eventUpdate.startsAt = update.startsAt;
    if (update.active !== undefined) eventUpdate.status = update.active ? 'open' : 'cancelled';
    const batch = db.batch();
    batch.update(ref, update);
    batch.set(db.collection('social_events').doc(clean(snap.data().socialEventId, 240)), eventUpdate, {merge: true});
    await batch.commit();
  } else {
    await ref.update(update);
  }
  return {ok: true};
});

exports.deleteBusinessContentItem = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await ownerContext(request, d.category, d.venueId);
  const type = clean(d.type, 20);
  const itemId = clean(d.itemId, 180);
  const cfg = configFor(type);
  if (!itemId) throw new HttpsError('invalid-argument', 'İçerik kimliği eksik.');
  const ref = db.collection('business_venues').doc(id).collection(cfg.collection).doc(itemId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'İçerik bulunamadı.');

  if (type === 'menu') {
    const storedPath = clean(snap.data()?.imageStoragePath, 600);
    const expected = `users/${uid}/business_menu/${id}/${itemId}/product.jpg`;
    if (storedPath === expected) {
      try { await getStorage().bucket().file(storedPath).delete({ignoreNotFound: true}); } catch (_) {}
    }
  }

  const batch = db.batch();
  batch.delete(ref);
  if (type === 'program' && snap.data()?.socialEventId) {
    batch.delete(db.collection('social_events').doc(clean(snap.data().socialEventId, 240)));
  }
  await batch.commit();
  return {ok: true};
});
