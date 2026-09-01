const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {getAuth} = require('firebase-admin/auth');

const MAX_ACTIVE_CLAIMS = 2;
const REJECT_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;

function requireAuth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}
function clean(value, max = 300) { return String(value || '').trim().slice(0, max); }
function venueKey(category, venueId) { return `${clean(category, 40)}:${clean(venueId, 180)}`; }

async function verifiedImageMetadata(path, maxBytes) {
  const file = getStorage().bucket().file(path);
  let metadata;
  try {
    const [exists] = await file.exists();
    if (!exists) throw new Error('missing');
    [metadata] = await file.getMetadata();
  } catch (_) {
    throw new HttpsError('failed-precondition', 'Görsel dosyası Storage üzerinde doğrulanamadı.');
  }
  const size = Number(metadata.size || 0);
  const contentType = String(metadata.contentType || '').toLowerCase();
  const allowedTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
  if (!Number.isFinite(size) || size <= 0 || size > maxBytes || !allowedTypes.has(contentType)) {
    throw new HttpsError('invalid-argument', 'Görsel dosyası türü veya boyutu geçersiz.');
  }
  return metadata;
}

async function verifyEvidenceFile(uid, id, evidenceStoragePath) {
  const expectedPath = `users/${uid}/business_claims/${id}/evidence.jpg`;
  if (evidenceStoragePath !== expectedPath) {
    throw new HttpsError('permission-denied', 'Kanıt dosyası bu hesap ve mekanla eşleşmiyor.');
  }
  await verifiedImageMetadata(expectedPath, 15 * 1024 * 1024);
}

exports.submitBusinessClaim = onCall({region: 'europe-west1'}, async (request) => {
  const uid = requireAuth(request);
  if (request.auth.token.email_verified !== true) throw new HttpsError('failed-precondition', 'E-posta doğrulaması gerekli.');
  const d = request.data || {};
  const category = clean(d.category, 40);
  const venueId = clean(d.venueId, 180);
  const venueName = clean(d.venueName, 180);
  const businessEmail = clean(d.businessEmail, 180).toLowerCase();
  const businessPhone = clean(d.businessPhone, 30);
  const legalName = clean(d.legalName, 180);
  const taxOffice = clean(d.taxOffice, 120);
  const taxNumberLast4 = clean(d.taxNumberLast4, 4);
  const evidenceUrl = clean(d.evidenceUrl, 1000);
  const evidenceStoragePath = clean(d.evidenceStoragePath, 500);

  if (!category || !venueId || !venueName || !businessEmail || businessPhone.length < 10 || legalName.length < 3) {
    throw new HttpsError('invalid-argument', 'Eksik işletme bilgisi.');
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(businessEmail)) throw new HttpsError('invalid-argument', 'İşletme e-posta adresi geçersiz.');
  if (!/^\d{4}$/.test(taxNumberLast4)) throw new HttpsError('invalid-argument', 'Vergi numarasının son 4 hanesi geçersiz.');

  const db = getFirestore();
  const id = venueKey(category, venueId);
  const ref = db.collection('business_claims').doc(id);
  const snap = await ref.get();
  const old = snap.data() || {};

  if (snap.exists) {
    if (old.status === 'verified') {
      if (old.applicantUid === uid) throw new HttpsError('failed-precondition', 'Bu mekan zaten hesabın için doğrulanmış.');
      throw new HttpsError('already-exists', 'Bu mekan zaten doğrulanmış bir işletme tarafından yönetiliyor.');
    }
    if (old.applicantUid && old.applicantUid !== uid && old.status !== 'rejected') {
      throw new HttpsError('already-exists', 'Bu mekan için başka bir doğrulama başvurusu incelemede.');
    }
    if (old.status === 'pending_review' && old.applicantUid === uid) {
      throw new HttpsError('failed-precondition', 'Bu işletme için başvurun zaten incelemede.');
    }
    if (old.status === 'rejected' && old.applicantUid === uid && old.updatedAt instanceof Timestamp) {
      const retryAt = old.updatedAt.toMillis() + REJECT_COOLDOWN_MS;
      if (retryAt > Date.now()) {
        const daysLeft = Math.max(1, Math.ceil((retryAt - Date.now()) / 86400000));
        throw new HttpsError('failed-precondition', `Bu işletme için yeniden başvuru göndermeden önce ${daysLeft} gün beklemelisin.`);
      }
    }
  }

  const ownClaims = await db.collection('business_claims').where('applicantUid', '==', uid).get();
  const activeCount = ownClaims.docs.filter(doc => doc.id !== id && doc.data().status === 'pending_review').length;
  if (activeCount >= MAX_ACTIVE_CLAIMS) {
    throw new HttpsError('resource-exhausted', 'Aynı anda en fazla 2 işletme doğrulama başvurusu incelemede olabilir.');
  }

  if (!evidenceUrl) throw new HttpsError('invalid-argument', 'Kanıt dosyası zorunlu.');
  await verifyEvidenceFile(uid, id, evidenceStoragePath);

  await ref.set({
    venueKey: id, venueId, category, venueName, applicantUid: uid,
    applicantEmail: clean(request.auth.token.email, 180), businessEmail, businessPhone,
    legalName, taxOffice, taxNumberLast4, evidenceUrl, evidenceStoragePath,
    status: 'pending_review', verificationLevel: 'none', adminReviewRequired: true,
    riskFlags: [], submittedAt: old.submittedAt || FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(), verifiedAt: null, verifiedBy: null,
    rejectionReason: '',
  }, {merge: false});
  return {status: 'pending_review'};
});

exports.getBusinessClaim = onCall({region: 'europe-west1'}, async (request) => {
  const uid = requireAuth(request);
  const d = request.data || {};
  const id = venueKey(d.category, d.venueId);
  const snap = await getFirestore().collection('business_claims').doc(id).get();
  if (!snap.exists) return {exists: false};
  const data = snap.data() || {};
  if (data.applicantUid !== uid && request.auth.token.admin !== true) {
    return {exists: true, status: data.status === 'verified' ? 'verified' : 'unavailable'};
  }
  return {exists: true, status: data.status, verificationLevel: data.verificationLevel || 'none', rejectionReason: data.rejectionReason || '', venueName: data.venueName || ''};
});

async function assertVerifiedOwner(request, category, venueId) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const id = venueKey(category, venueId);
  const claim = await db.collection('business_claims').doc(id).get();
  const data = claim.data() || {};
  if (data.status !== 'verified' || data.applicantUid !== uid) throw new HttpsError('permission-denied', 'Yalnız doğrulanmış işletme sahibi bu işlemi yapabilir.');
  return {uid, db, id};
}

exports.updateBusinessProfile = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await assertVerifiedOwner(request, d.category, d.venueId);
  const description = clean(d.description, 1200);
  const phone = clean(d.phone, 40);
  const website = clean(d.website, 500);
  const openingHours = clean(d.openingHours, 500);
  if (phone && phone.replace(/\D/g, '').length < 10) throw new HttpsError('invalid-argument', 'İşletme telefonu geçersiz.');
  if (website && !/^https?:\/\//i.test(website) && !/^[\w.-]+\.[a-z]{2,}/i.test(website)) throw new HttpsError('invalid-argument', 'Web sitesi adresi geçersiz.');
  await db.collection('business_venues').doc(id).set({ownerUid: uid, verified: true, description, phone, website, openingHours, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {ok: true};
});

exports.updateBusinessProfileMedia = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await assertVerifiedOwner(request, d.category, d.venueId);
  const kind = clean(d.kind, 20);
  const imageUrl = clean(d.imageUrl, 1200);
  const storagePath = clean(d.storagePath, 600);
  if (!['logo', 'cover'].includes(kind) || !imageUrl) throw new HttpsError('invalid-argument', 'İşletme görseli bilgileri geçersiz.');
  const expectedPath = `users/${uid}/business_profiles/${id}/${kind}.jpg`;
  if (storagePath !== expectedPath) throw new HttpsError('permission-denied', 'İşletme görseli bu hesap ve mekanla eşleşmiyor.');
  await verifiedImageMetadata(expectedPath, 12 * 1024 * 1024);
  const field = kind === 'logo' ? 'logoUrl' : 'coverUrl';
  const pathField = kind === 'logo' ? 'logoStoragePath' : 'coverStoragePath';
  await db.collection('business_venues').doc(id).set({ownerUid: uid, verified: true, [field]: imageUrl, [pathField]: storagePath, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {ok: true};
});

exports.addBusinessMenuItem = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await assertVerifiedOwner(request, d.category, d.venueId);
  const name = clean(d.name, 120), section = clean(d.section, 80), description = clean(d.description, 500), priceMinor = Number(d.priceMinor || 0);
  if (!name || !section || !Number.isInteger(priceMinor) || priceMinor < 0 || priceMinor > 100000000) throw new HttpsError('invalid-argument', 'Menü bilgileri geçersiz.');
  const venueRef = db.collection('business_venues').doc(id);
  await venueRef.set({ownerUid: uid, verified: true, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  await venueRef.collection('menu').add({name, section, description, priceMinor, currency: 'TRY', active: true, createdBy: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
  return {ok: true};
});

exports.addBusinessProgramItem = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await assertVerifiedOwner(request, d.category, d.venueId);
  const title = clean(d.title, 160), description = clean(d.description, 700), startsAtMs = Number(d.startsAtMs || 0);
  if (!title || !Number.isFinite(startsAtMs) || startsAtMs < Date.now() - 60000) throw new HttpsError('invalid-argument', 'Program bilgileri geçersiz.');
  const venueRef = db.collection('business_venues').doc(id);
  const venue = (await venueRef.get()).data() || {};
  const programRef = venueRef.collection('program').doc();
  const eventRef = db.collection('social_events').doc(`business_${programRef.id}`);
  const venueName = clean(venue.venueName || d.venueName || 'Doğrulanmış işletme', 160);
  const city = clean(venue.city || '', 80);
  const latitude = Number(venue.latitude);
  const longitude = Number(venue.longitude);
  const startsAt = Timestamp.fromMillis(startsAtMs);
  const batch = db.batch();
  batch.set(venueRef, {ownerUid: uid, verified: true, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  batch.set(programRef, {title, description, startsAt, active: true, createdBy: uid, socialEventId: eventRef.id, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
  batch.set(eventRef, {
    id: eventRef.id, title, description, startsAt,
    type: 'other', customTypeLabel: 'İşletme etkinliği',
    hostId: uid, hostName: venueName, capacity: 500,
    participantIds: [], city, locationLabel: venueName,
    latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null,
    status: 'open', visibility: 'public', allowedUserIds: [],
    approximateLocationOnly: false, accessType: 'free', ticketPriceMinor: 0,
    currency: 'TRY', paymentStatus: 'notRequired', trustStatus: 'verified_business',
    salesStatus: 'not_required', riskLevel: 'low', reportCount: 0,
    paymentReleaseStatus: 'not_applicable', interestedCount: 0,
    privateParticipantCount: 0, source: 'business_program',
    businessVenueKey: id, businessVenueName: venueName,
    businessProgramId: programRef.id, verifiedBusiness: true,
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {ok: true, id: programRef.id, socialEventId: eventRef.id};
});

exports.addBusinessCampaign = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await assertVerifiedOwner(request, d.category, d.venueId);
  const title = clean(d.title, 140), description = clean(d.description, 700), validUntilMs = Number(d.validUntilMs || 0);
  if (!title || !description || !Number.isFinite(validUntilMs) || validUntilMs < Date.now()) throw new HttpsError('invalid-argument', 'Kampanya bilgileri geçersiz.');
  const venueRef = db.collection('business_venues').doc(id);
  await venueRef.set({ownerUid: uid, verified: true, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  await venueRef.collection('campaigns').add({title, description, validUntil: Timestamp.fromMillis(validUntilMs), active: true, createdBy: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
  return {ok: true};
});

async function reviewBusinessClaimCore({uid, token, data: d}) {
  if (!uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (token?.admin !== true) throw new HttpsError('permission-denied', 'Admin yetkisi gerekli.');
  const id = venueKey(d?.category, d?.venueId);
  const decision = clean(d?.decision, 20);
  if (!['verified', 'rejected'].includes(decision)) throw new HttpsError('invalid-argument', 'Geçersiz karar.');
  const db = getFirestore(), ref = db.collection('business_claims').doc(id), snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Başvuru bulunamadı.');
  const data = snap.data() || {};
  if (data.status !== 'pending_review') throw new HttpsError('failed-precondition', 'Yalnız incelemedeki başvurular sonuçlandırılabilir.');
  const update = {status: decision, verificationLevel: decision === 'verified' ? 'manual_strong' : 'none', adminReviewRequired: false, verifiedAt: decision === 'verified' ? FieldValue.serverTimestamp() : null, verifiedBy: decision === 'verified' ? uid : null, rejectionReason: decision === 'rejected' ? clean(d?.reason, 500) : '', updatedAt: FieldValue.serverTimestamp()};
  await ref.update(update);
  if (decision === 'verified') {
    await db.collection('business_venues').doc(id).set({ownerUid: data.applicantUid, venueId: data.venueId, category: data.category, venueName: data.venueName, verified: true, verificationLevel: 'manual_strong', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  }
  return {status: decision};
}

exports.adminReviewBusinessClaim = onCall({region: 'europe-west1', invoker: 'public'}, async (request) => {
  return reviewBusinessClaimCore({uid: request.auth?.uid, token: request.auth?.token, data: request.data || {}});
});

exports.adminReviewBusinessClaimHttp = onRequest({region: 'europe-west1', invoker: 'public', cors: true}, async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({error: 'method-not-allowed', message: 'Yalnız POST desteklenir.'});
    return;
  }
  try {
    const header = String(req.get('authorization') || '');
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
    const decoded = await getAuth().verifyIdToken(match[1], true);
    const result = await reviewBusinessClaimCore({uid: decoded.uid, token: decoded, data: req.body || {}});
    res.status(200).json(result);
  } catch (error) {
    const code = error?.code || 'internal';
    const message = error?.message || 'İşletme başvurusu işlenemedi.';
    const status = code === 'unauthenticated' ? 401 : code === 'permission-denied' ? 403 : code === 'not-found' ? 404 : code === 'invalid-argument' ? 400 : code === 'failed-precondition' ? 409 : 500;
    res.status(status).json({error: code, message});
  }
});
