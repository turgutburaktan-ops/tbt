const {createHash} = require('node:crypto');
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

async function citySpots(db, city, tx) {
  const queries = [db.collection('photo_spots').where('cityKey','==',cityKey(city)),
    db.collection('photo_spots').where('city','==',city)];
  const rows = await Promise.all(queries.map(q => tx ? tx.get(q) : q.get()));
  return [...new Map(rows.flatMap(s => s.docs).map(d => [d.id,d])).values()];
}
function similarPlace(a,b) {
  if (cityKey(a.name) === cityKey(b.name)) return true;
  const lat = Number(a.latitude), lon = Number(a.longitude);
  if (!validCoord(lat,lon)) return false;
  const radians = Math.PI / 180;
  const x = (lon-b.longitude) * Math.cos((lat+b.latitude)*radians/2);
  const y = lat-b.latitude;
  return Math.hypot(x,y)*111320 < 50;
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
  const sourceRouteId = clean(d.sourceRouteId, 200);
  const sourceStopId = clean(d.sourceStopId, 200);
  if (Boolean(sourceRouteId) !== Boolean(sourceStopId) || sourceRouteId.includes('/') || sourceStopId.includes('/')) {
    throw new HttpsError('invalid-argument', 'Rota ve durak bilgisi geçersiz.');
  }
  if (sourceRouteId) {
    const route = (await db.collection('travel_plans').doc(sourceRouteId).get()).data();
    if (!route || !(route.memberIds || []).includes(uid)) {
      throw new HttpsError('permission-denied', 'Yalnızca katıldığın rotadan yer önerebilirsin.');
    }
    const stop = (route.stopSnapshots || []).find(x => x.id === sourceStopId);
    if (!stop || !(sourceStopId.startsWith('custom_') || sourceStopId.startsWith('map:')) || stop.venue) {
      throw new HttpsError('failed-precondition', 'Yalnızca rotadaki özel durakları Gezi’ye önerebilirsin.');
    }
  }
  const ref = sourceRouteId
    ? db.collection('spot_submissions').doc('route_' + createHash('sha256').update(JSON.stringify([uid,sourceRouteId,sourceStopId])).digest('hex'))
    : db.collection('spot_submissions').doc();
  const candidates = await citySpots(db, city);
  const pending = await db.collection('spot_submissions').where('cityKey','==',cityKey(city)).get();
  const duplicates = [...candidates, ...pending.docs.filter(x => x.id !== ref.id && ['pending_review','approved'].includes(x.data().status))]
    .filter(doc => similarPlace(doc.data(), {name, latitude, longitude}));
  const duplicate = duplicates.length > 0;

  return db.runTransaction(async tx => {
    const old = await tx.get(ref);
    if (old.exists && old.data().status !== 'rejected') {
      return {id:ref.id, status:old.data().status, alreadySubmitted:true, duplicateWarning:old.data().duplicateWarning === true};
    }
    tx.set(ref, {

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
    sourceType: sourceRouteId ? 'route_stop' : 'user_suggestion',
    ...(sourceRouteId ? {sourceRouteId,sourceStopId} : {}),
    duplicateCandidates: duplicates.slice(0,10).map(x => ({id:x.id, name:x.data().name || ''})),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {id: ref.id, status: 'pending_review', duplicateWarning: duplicate};
  });
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
      duplicateCandidates: d.duplicateCandidates || [],
      sourceType: d.sourceType || '',
      sourceRouteId: d.sourceRouteId || '',
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
  if (!submissionId || submissionId.includes('/') || !['approved','rejected','duplicate'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'Geçersiz inceleme kararı.');
  }
  const db = getFirestore();
  const ref = db.collection('spot_submissions').doc(submissionId);
  return db.runTransaction(async tx => {
  const snap = await tx.get(ref);
  if (!snap.exists) throw new HttpsError('not-found', 'Yer önerisi bulunamadı.');
  const data = snap.data() || {};
  if (String(data.status || '') !== 'pending_review') throw new HttpsError('failed-precondition', 'Bu öneri daha önce sonuçlandırılmış.');

  if (decision === 'approved') {
    // Serialize approvals within a city, including two different submissions of the same place.
    const lock = db.collection('spot_submission_review_locks').doc(data.cityKey);
    await tx.get(lock);
    const existing = await citySpots(db, data.city, tx);
    if (existing.some(x => similarPlace(x.data(),data))) {
      throw new HttpsError('already-exists', 'Aynı isimde veya konumda bir yer zaten var. Mükerrer olarak işaretle.');
    }
    tx.set(lock, {updatedAt:FieldValue.serverTimestamp()});
    const spotRef = db.collection('photo_spots').doc(`user_${submissionId}`);
    tx.set(spotRef, {
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

  tx.update(ref, {
    status: decision === 'approved' ? 'approved' : decision,
    reviewReason: reason,
    reviewedBy: request.auth.uid,
    reviewedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {status: decision};
  });
});
