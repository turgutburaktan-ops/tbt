const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

function clean(value, max = 1000) {
  return String(value || '').trim().slice(0, max);
}

exports.setSocialEventCover = onCall({region: 'europe-west1'}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');

  const eventId = clean(request.data?.eventId, 180);
  const coverImageUrl = clean(request.data?.coverImageUrl, 1400);
  const coverStoragePath = clean(request.data?.coverStoragePath, 600);
  if (!eventId || !coverImageUrl || !coverStoragePath) {
    throw new HttpsError('invalid-argument', 'Etkinlik kapak bilgisi eksik.');
  }

  const expectedPath = `users/${uid}/events/${eventId}/cover.jpg`;
  if (coverStoragePath !== expectedPath) {
    throw new HttpsError('permission-denied', 'Kapak dosyası bu kullanıcı ve etkinlikle eşleşmiyor.');
  }

  const db = getFirestore();
  const eventRef = db.collection('social_events').doc(eventId);
  const eventSnap = await eventRef.get();
  if (!eventSnap.exists) throw new HttpsError('not-found', 'Etkinlik bulunamadı.');
  const event = eventSnap.data() || {};
  if (String(event.hostId || '') !== uid) {
    throw new HttpsError('permission-denied', 'Yalnız etkinlik sahibi kapak fotoğrafını değiştirebilir.');
  }

  const file = getStorage().bucket().file(expectedPath);
  const [exists] = await file.exists();
  if (!exists) throw new HttpsError('failed-precondition', 'Kapak fotoğrafı Storage üzerinde bulunamadı.');
  const [metadata] = await file.getMetadata();
  const size = Number(metadata.size || 0);
  const contentType = String(metadata.contentType || '').toLowerCase();
  if (!Number.isFinite(size) || size <= 0 || size > 15 * 1024 * 1024 || contentType !== 'image/jpeg') {
    throw new HttpsError('invalid-argument', 'Kapak fotoğrafının türü veya boyutu geçersiz.');
  }

  await eventRef.update({
    coverImageUrl,
    coverStoragePath,
    coverImageUpdatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});
