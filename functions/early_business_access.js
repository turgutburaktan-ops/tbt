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
  const until = data.earlyAccessUntil instanceof Timestamp ? data.earlyAccessUntil.toMillis() : 0;
  const adminUntil = data.adminPremiumUntil instanceof Timestamp ? data.adminPremiumUntil.toMillis() : 0;
  const paid = data.subscriptionStatus === 'active';
  const admin = data.adminPremiumStatus === 'active' && adminUntil > now;
  const early = data.earlyAccessStatus === 'active' && until > now;
  return {
    entitled: paid || admin || early,
    source: paid ? 'paid' : admin ? 'admin_grant' : early ? 'early_access' : 'none',
    earlyAccessActive: early,
    earlyAccessUntilMs: until,
    adminPremiumActive: admin,
    adminPremiumUntilMs: adminUntil,
    plan: String(data.plan || (admin ? 'business_pro' : early ? EARLY_ACCESS_PLAN : 'free')),
  };
}

async function grantEarlyAccess(db, claimId, ownerUid) {
  const until = Timestamp.fromMillis(Date.now() + EARLY_ACCESS_DAYS * 24 * 60 * 60 * 1000);
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
    db.collection('business_claims').doc(claimId).set(entitlement, {merge: true}),
    db.collection('business_venues').doc(claimId).set({
      ...entitlement,
      ownerUid: ownerUid || null,
      verified: true,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
  ]);
  return {...entitlement, earlyAccessUntil: until};
}

exports.grantEarlyBusinessAccessOnVerification = onDocumentUpdated(
  {document: 'business_claims/{claimId}', region: 'europe-west1'},
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (before.status === 'verified' || after.status !== 'verified') return;
    await grantEarlyAccess(getFirestore(), event.params.claimId, after.applicantUid);
  }
);

exports.getBusinessEntitlement = onCall({region: 'europe-west1'}, async (request) => {
  const uid = requireAuth(request);
  const claimId = String(request.data?.venueKey || '').trim();
  if (!claimId || claimId.length > 240) throw new HttpsError('invalid-argument', 'Mekan kimliği geçersiz.');
  const db = getFirestore();
  const ref = db.collection('business_claims').doc(claimId);
  const snap = await ref.get();
  if (!snap.exists) return {exists: false, entitled: false, source: 'none'};
  let data = snap.data() || {};
  if (data.applicantUid !== uid && request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Bu işletmenin plan bilgisine erişemezsin.');
  }
  if (data.status !== 'verified') return {exists: true, verified: false, entitled: false, source: 'none'};

  if (!data.earlyAccessStatus && data.subscriptionStatus !== 'active' && data.adminPremiumStatus !== 'active') {
    const granted = await grantEarlyAccess(db, claimId, data.applicantUid);
    data = {...data, ...granted};
  }

  return {exists: true, verified: true, ...entitlementFor(data)};
});
