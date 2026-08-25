const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {randomUUID} = require('crypto');

const MAX_ACTIVE_CLAIMS = 2;
const REJECT_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_EVIDENCE_BYTES = 10 * 1024 * 1024;

function clean(value, max = 300) { return String(value || '').trim().slice(0, max); }
function venueKey(category, venueId) { return `${clean(category, 40)}:${clean(venueId, 180)}`; }
function requireAuth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}

exports.submitBusinessClaimV2 = onCall({region: 'europe-west1', timeoutSeconds: 60, memory: '512MiB'}, async request => {
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
  const evidenceContentType = clean(d.evidenceContentType, 80).toLowerCase();
  const evidenceBase64 = String(d.evidenceBase64 || '');

  if (!['cafe', 'dining', 'hotel'].includes(category) || !venueId || venueName.length < 2 || legalName.length < 3 || taxOffice.length < 2) {
    throw new HttpsError('invalid-argument', 'Eksik veya geçersiz işletme bilgisi.');
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(businessEmail)) {
    throw new HttpsError('invalid-argument', 'İşletme e-posta adresi geçersiz.');
  }
  if (businessPhone.replace(/\D/g, '').length < 10) {
    throw new HttpsError('invalid-argument', 'İşletme telefonu geçersiz.');
  }
  if (!/^\d{4}$/.test(taxNumberLast4)) {
    throw new HttpsError('invalid-argument', 'Vergi numarasının son 4 hanesi geçersiz.');
  }
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(evidenceContentType)) {
    throw new HttpsError('invalid-argument', 'Kanıt görseli JPEG, PNG veya WebP olmalı.');
  }

  let evidence;
  try { evidence = Buffer.from(evidenceBase64, 'base64'); } catch (_) {
    throw new HttpsError('invalid-argument', 'Kanıt görseli okunamadı.');
  }
  if (!evidence.length || evidence.length > MAX_EVIDENCE_BYTES) {
    throw new HttpsError('invalid-argument', 'Kanıt görseli 10 MB sınırını aşıyor veya boş.');
  }

  const db = getFirestore();
  const id = venueKey(category, venueId);
  const ref = db.collection('business_claims').doc(id);
  const snap = await ref.get();
  const old = snap.data() || {};

  if (snap.exists) {
    if (old.status === 'verified') {
      if (old.applicantUid === uid) throw new HttpsError('failed-precondition', 'Bu işletme zaten hesabın için doğrulanmış.');
      throw new HttpsError('already-exists', 'Bu işletme zaten doğrulanmış bir hesap tarafından yönetiliyor.');
    }
    if (old.applicantUid && old.applicantUid !== uid && old.status !== 'rejected') {
      throw new HttpsError('already-exists', 'Bu işletme için başka bir doğrulama başvurusu incelemede.');
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

  const ext = evidenceContentType === 'image/png' ? 'png' : evidenceContentType === 'image/webp' ? 'webp' : 'jpg';
  const evidenceStoragePath = `users/${uid}/business_claims/${id}/evidence.${ext}`;
  const token = randomUUID();
  const bucket = getStorage().bucket();
  await bucket.file(evidenceStoragePath).save(evidence, {
    resumable: false,
    contentType: evidenceContentType,
    metadata: {metadata: {firebaseStorageDownloadTokens: token}},
  });
  const evidenceUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(evidenceStoragePath)}?alt=media&token=${token}`;

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
