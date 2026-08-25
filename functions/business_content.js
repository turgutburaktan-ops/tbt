const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

function clean(value, max = 500) {
  return String(value || '').trim().slice(0, max);
}

function venueKey(category, venueId) {
  return `${clean(category, 40)}:${clean(venueId, 180)}`;
}

function requireAuth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}

async function ownerContext(request, category, venueId) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const id = venueKey(category, venueId);
  const snap = await db.collection('business_claims').doc(id).get();
  const data = snap.data() || {};
  if (data.status !== 'verified' || data.applicantUid !== uid) {
    throw new HttpsError('permission-denied', 'Yalnız doğrulanmış işletme sahibi bu işlemi yapabilir.');
  }
  return {uid, db, id};
}

function configFor(type) {
  if (type === 'menu') return {collection: 'menu'};
  if (type === 'campaign') return {collection: 'campaigns'};
  if (type === 'program') return {collection: 'program'};
  throw new HttpsError('invalid-argument', 'Geçersiz içerik türü.');
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
    if (d.priceMinor !== undefined) {
      const price = Number(d.priceMinor);
      if (!Number.isInteger(price) || price < 0 || price > 100000000) {
        throw new HttpsError('invalid-argument', 'Fiyat bilgisi geçersiz.');
      }
      update.priceMinor = price;
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

  await ref.update(update);
  return {ok: true};
});

exports.deleteBusinessContentItem = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {db, id} = await ownerContext(request, d.category, d.venueId);
  const type = clean(d.type, 20);
  const itemId = clean(d.itemId, 180);
  const cfg = configFor(type);
  if (!itemId) throw new HttpsError('invalid-argument', 'İçerik kimliği eksik.');
  const ref = db.collection('business_venues').doc(id).collection(cfg.collection).doc(itemId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'İçerik bulunamadı.');
  await ref.delete();
  return {ok: true};
});
