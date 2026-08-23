const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

function requireAuth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}

function clean(value, max = 300) {
  return String(value || '').trim().slice(0, max);
}

function venueKey(category, venueId) {
  return `${clean(category, 40)}:${clean(venueId, 180)}`;
}

exports.submitBusinessClaim = onCall({region: 'europe-west1'}, async (request) => {
  const uid = requireAuth(request);
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'E-posta doğrulaması gerekli.');
  }
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
  if (!/^\d{4}$/.test(taxNumberLast4)) {
    throw new HttpsError('invalid-argument', 'Vergi numarasının son 4 hanesi geçersiz.');
  }
  const expectedPrefix = `users/${uid}/business_claims/`;
  if (!evidenceUrl || !evidenceStoragePath.startsWith(expectedPrefix)) {
    throw new HttpsError('permission-denied', 'Kanıt dosyası bu hesaba ait değil.');
  }

  const db = getFirestore();
  const id = venueKey(category, venueId);
  const ref = db.collection('business_claims').doc(id);
  const snap = await ref.get();
  const old = snap.data() || {};
  if (old.status === 'verified' && old.applicantUid !== uid) {
    throw new HttpsError('already-exists', 'Bu mekan zaten doğrulanmış bir işletme tarafından yönetiliyor.');
  }

  await ref.set({
    venueKey: id,
    venueId,
    category,
    venueName,
    applicantUid: uid,
    applicantEmail: clean(request.auth.token.email, 180),
    businessEmail,
    businessPhone,
    legalName,
    taxOffice,
    taxNumberLast4,
    evidenceUrl,
    evidenceStoragePath,
    status: 'pending_review',
    verificationLevel: 'none',
    adminReviewRequired: true,
    riskFlags: [],
    submittedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    verifiedAt: null,
    verifiedBy: null,
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
  return {
    exists: true,
    status: data.status,
    verificationLevel: data.verificationLevel || 'none',
    rejectionReason: data.rejectionReason || '',
    venueName: data.venueName || '',
  };
});

async function assertVerifiedOwner(request, category, venueId) {
  const uid = requireAuth(request);
  const db = getFirestore();
  const id = venueKey(category, venueId);
  const claim = await db.collection('business_claims').doc(id).get();
  const data = claim.data() || {};
  if (data.status !== 'verified' || data.applicantUid !== uid) {
    throw new HttpsError('permission-denied', 'Yalnız doğrulanmış işletme sahibi bu işlemi yapabilir.');
  }
  return {uid, db, id};
}

exports.addBusinessMenuItem = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await assertVerifiedOwner(request, d.category, d.venueId);
  const name = clean(d.name, 120);
  const section = clean(d.section, 80);
  const description = clean(d.description, 500);
  const priceMinor = Number(d.priceMinor || 0);
  if (!name || !section || !Number.isInteger(priceMinor) || priceMinor < 0 || priceMinor > 100000000) {
    throw new HttpsError('invalid-argument', 'Menü bilgileri geçersiz.');
  }
  const venueRef = db.collection('business_venues').doc(id);
  await venueRef.set({ownerUid: uid, verified: true, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  await venueRef.collection('menu').add({
    name, section, description, priceMinor, currency: 'TRY', active: true,
    createdBy: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

exports.addBusinessProgramItem = onCall({region: 'europe-west1'}, async (request) => {
  const d = request.data || {};
  const {uid, db, id} = await assertVerifiedOwner(request, d.category, d.venueId);
  const title = clean(d.title, 160);
  const description = clean(d.description, 700);
  const startsAtMs = Number(d.startsAtMs || 0);
  if (!title || !Number.isFinite(startsAtMs) || startsAtMs < Date.now() - 60000) {
    throw new HttpsError('invalid-argument', 'Program bilgileri geçersiz.');
  }
  const venueRef = db.collection('business_venues').doc(id);
  await venueRef.set({ownerUid: uid, verified: true, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  await venueRef.collection('program').add({
    title, description, startsAt: Timestamp.fromMillis(startsAtMs), active: true,
    createdBy: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

exports.adminReviewBusinessClaim = onCall({region: 'europe-west1'}, async (request) => {
  requireAuth(request);
  if (request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Admin yetkisi gerekli.');
  }
  const d = request.data || {};
  const id = venueKey(d.category, d.venueId);
  const decision = clean(d.decision, 20);
  if (!['verified', 'rejected'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'Geçersiz karar.');
  }
  const db = getFirestore();
  const ref = db.collection('business_claims').doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Başvuru bulunamadı.');
  const data = snap.data() || {};
  const update = {
    status: decision,
    verificationLevel: decision === 'verified' ? 'manual_strong' : 'none',
    adminReviewRequired: false,
    verifiedAt: decision === 'verified' ? FieldValue.serverTimestamp() : null,
    verifiedBy: decision === 'verified' ? request.auth.uid : null,
    rejectionReason: decision === 'rejected' ? clean(d.reason, 500) : '',
    updatedAt: FieldValue.serverTimestamp(),
  };
  await ref.update(update);
  if (decision === 'verified') {
    await db.collection('business_venues').doc(id).set({
      ownerUid: data.applicantUid,
      venueId: data.venueId,
      category: data.category,
      venueName: data.venueName,
      verified: true,
      verificationLevel: 'manual_strong',
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  return {status: decision};
});
