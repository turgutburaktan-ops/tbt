const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

function clean(value, max = 500) { return String(value || '').trim().slice(0, max); }
function requireAuth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}
function requireAdmin(request) {
  requireAuth(request);
  if (request.auth.token.admin !== true || String(request.auth.token.email || '').toLowerCase() !== 'turgutburaktan@gmail.com') {
    throw new HttpsError('permission-denied', 'Bu panel yalnız tanımlı yönetici hesabına açıktır.');
  }
}
function validCoord(lat, lon) {
  return Number.isFinite(lat) && Number.isFinite(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
}
function cityKey(value) {
  return clean(value, 100).toLocaleLowerCase('tr-TR')
    .replace(/ı/g, 'i').replace(/ş/g, 's').replace(/ğ/g, 'g').replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ç/g, 'c');
}

exports.submitSpotSuggestion = onCall({region: 'europe-west1'}, async (request) => {
  const uid = requireAuth(request);
  const d = request.data || {};
  const name = clean(d.name, 140);
  const city = clean(d.city, 100);
  const district = clean(d.district, 100);
  const description = clean(d.description, 1200);
  const whyVisit = clean(d.whyVisit, 700);
  const imageUrl = clean(d.imageUrl, 1600);
  const imageStoragePath = clean(d.imageStoragePath, 700);
  const latitude = Number(d.latitude);
  const longitude = Number(d.longitude);

  if (name.length < 3 || city.length < 2 || description.length < 10 || whyVisit.length < 5) {
    throw new HttpsError('invalid-argument', 'Yer adı, şehir, açıklama ve neden görülmeli alanlarını doldur.');
  }
  if (!validCoord(latitude, longitude)) throw new HttpsError('invalid-argument', 'Haritadan geçerli bir konum seç.');
  if (!imageUrl || !imageStoragePath) throw new HttpsError('invalid-argument', 'En az bir fotoğraf eklemelisin.');
  const expectedPrefix = `users/${uid}/spot_submissions/`;
  if (!imageStoragePath.startsWith(expectedPrefix)) throw new HttpsError('permission-denied', 'Fotoğraf bu hesapla eşleşmiyor.');

  const db = getFirestore();
  const ref = db.collection('spot_submissions').doc();
  const near = await db.collection('photo_spots').where('cityKey', '==', cityKey(city)).limit(100).get();
  const duplicate = near.docs.some(doc => {
    const x = doc.data() || {};
    const lat = Number(x.latitude), lon = Number(x.longitude);
    if (!validCoord(lat, lon)) return false;
    const dLat = Math.abs(lat - latitude), dLon = Math.abs(lon - longitude);
    const sameName = clean(x.name, 140).toLocaleLowerCase('tr-TR') === name.toLocaleLowerCase('tr-TR');
    return sameName || (dLat < 0.0012 && dLon < 0.0012);
  });

  await ref.set({
    id: ref.id,
    name, city, district,
    cityKey: cityKey(city),
    category: 'Gezilecek Yerler',
    latitude, longitude,
    description, whyVisit,
    imageUrl, imageStoragePath,
    submittedBy: uid,
    submittedByEmail: clean(request.auth.token.email, 180),
    status: 'pending_review',
    duplicateWarning: duplicate,
    sourceType: 'user_suggestion',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {id: ref.id, status: 'pending_review', duplicateWarning: duplicate};
});

exports.listPendingSpotSuggestions = onCall({region: 'europe-west1'}, async (request) => {
  requireAdmin(request);
  const snap = await getFirestore().collection('spot_submissions').where('status', '==', 'pending_review').limit(200).get();
  const items = snap.docs.map(doc => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      name: d.name || '', city: d.city || '', district: d.district || '',
      description: d.description || '', whyVisit: d.whyVisit || '', imageUrl: d.imageUrl || '',
      latitude: d.latitude || 0, longitude: d.longitude || 0,
      duplicateWarning: d.duplicateWarning === true,
      createdAtMs: d.createdAt?.toMillis?.() || 0,
    };
  }).sort((a,b) => b.createdAtMs - a.createdAtMs);
  return {items};
});

exports.reviewSpotSuggestion = onCall({region: 'europe-west1'}, async (request) => {
  requireAdmin(request);
  const d = request.data || {};
  const submissionId = clean(d.submissionId, 200);
  const decision = clean(d.decision, 20);
  const reason = clean(d.reason, 500);
  if (!submissionId || !['approved','rejected','duplicate'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'Geçersiz inceleme kararı.');
  }
  const db = getFirestore();
  const ref = db.collection('spot_submissions').doc(submissionId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Yer önerisi bulunamadı.');
  const data = snap.data() || {};
  if (String(data.status || '') !== 'pending_review') throw new HttpsError('failed-precondition', 'Bu öneri daha önce sonuçlandırılmış.');

  if (decision === 'approved') {
    const spotRef = db.collection('photo_spots').doc(`user_${submissionId}`);
    await spotRef.set({
      id: spotRef.id,
      name: data.name,
      city: data.city,
      cityKey: data.cityKey,
      latitude: data.latitude,
      longitude: data.longitude,
      category: 'Gezilecek Yerler',
      description: data.description,
      imageUrl: data.imageUrl,
      imageVerified: true,
      coordinateVerified: true,
      rating: 0,
      bestTime: 'Gün ışığına göre kontrol et',
      angle: 'Noktada farklı açılar dene',
      recommendedLens: '24-70mm',
      difficulty: 'Kolay',
      tags: ['Topluluk Önerisi'],
      sourceType: 'user_approved',
      submittedBy: data.submittedBy,
      status: 'published',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: false});
  }

  await ref.update({
    status: decision === 'approved' ? 'approved' : decision,
    reviewReason: reason,
    reviewedBy: request.auth.uid,
    reviewedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {status: decision};
});
