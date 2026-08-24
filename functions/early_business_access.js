const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

const EARLY_ACCESS_DAYS = 180;
const EARLY_ACCESS_PLAN = 'early_business_premium';

function requireAuth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}

function entitlementFor(data) {
  const now = Date.now();
  const until = data.earlyAccessUntil instanceof Timestamp
    ? data.earlyAccessUntil.toMillis()
    : 0;
  const paid = data.subscriptionStatus === 'active';
  const early = data.earlyAccessStatus === 'active' && until > now;
  return {
    entitled: paid || early,
    source: paid ? 'paid' : early ? 'early_access' : 'none',
    earlyAccessActive: early,
    earlyAccessUntilMs: until,
    plan: String(data.plan || (early ? EARLY_ACCESS_PLAN : 'free')),
  };
}

exports.grantEarlyBusinessAccessOnVerification = onDocumentUpdated(
  {document: 'business_claims/{claimId}', region: 'europe-west1'},
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (before.status === 'verified' || after.status !== 'verified') return;

    const db = getFirestore();
    const claimId = event.params.claimId;
    const claimRef = db.collection('business_claims').doc(claimId);
    const venueRef = db.collection('business_venues').doc(claimId);
    const startMs = Date.now();
    const until = Timestamp.fromMillis(startMs + EARLY_ACCESS_DAYS * 24 * 60 * 60 * 1000);
    const entitlement = {
      plan: EARLY_ACCESS_PLAN,
      earlyAccessStatus: 'active',
      earlyAccessStartedAt: FieldValue.serverTimestamp(),
      earlyAccessUntil: until,
      subscriptionStatus: 'none',
      billingRequired: false,
      premiumEntitled: true,
      premiumReason: 'verified_early_business',
      premiumUpdatedAt: FieldValue.serverTimestamp(),
    };

    await Promise.all([
      claimRef.set(entitlement, {merge: true}),
      venueRef.set({
        ...entitlement,
        ownerUid: after.applicantUid || null,
        verified: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
    ]);
  }
);

exports.getBusinessEntitlement = onCall({region: 'europe-west1'}, async (request) => {
  const uid = requireAuth(request);
  const claimId = String(request.data?.venueKey || '').trim();
  if (!claimId || claimId.length > 240) {
    throw new HttpsError('invalid-argument', 'Mekan kimliği geçersiz.');
  }
  const snap = await getFirestore().collection('business_claims').doc(claimId).get();
  if (!snap.exists) return {exists: false, entitled: false, source: 'none'};
  const data = snap.data() || {};
  if (data.applicantUid !== uid && request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Bu işletmenin plan bilgisine erişemezsin.');
  }
  if (data.status !== 'verified') {
    return {exists: true, verified: false, entitled: false, source: 'none'};
  }
  return {exists: true, verified: true, ...entitlementFor(data)};
});
