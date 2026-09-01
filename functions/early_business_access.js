const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

const PREMIUM_TRIAL_DAYS = 30;

function requireAuth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}

function entitlementFor(data) {
  const now = Date.now();
  const trialUntil = data.premiumTrialUntil instanceof Timestamp ? data.premiumTrialUntil.toMillis() : 0;
  const adminUntil = data.adminPremiumUntil instanceof Timestamp ? data.adminPremiumUntil.toMillis() : 0;
  const paid = data.subscriptionStatus === 'active';
  const admin = data.adminPremiumStatus === 'active' && adminUntil > now;
  const trial = data.premiumTrialStatus === 'active' && trialUntil > now;
  return {
    entitled: true,
    proEntitled: true,
    premiumEntitled: paid || admin || trial,
    source: 'free_pro',
    premiumSource: paid ? 'paid' : admin ? 'admin_grant' : trial ? 'trial' : 'none',
    premiumTrialActive: trial,
    premiumTrialUntilMs: trialUntil,
    premiumTrialUsed: data.premiumTrialStartedAt != null,
    adminPremiumActive: admin,
    adminPremiumUntilMs: adminUntil,
    plan: paid || admin || trial ? 'business_premium' : 'business_pro_free',
  };
}

async function grantEarlyAccess(db, claimId, ownerUid) {
  const entitlement = {
    plan: 'business_pro_free',
    proEntitled: true,
    proGrantedAt: FieldValue.serverTimestamp(),
    subscriptionStatus: 'none',
    billingRequired: false,
    premiumEntitled: false,
    premiumReason: 'none',
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
  return entitlement;
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

  return {exists: true, verified: true, ...entitlementFor(data)};
});

exports.startBusinessPremiumTrial = onCall({region: 'europe-west1'}, async (request) => {
  const uid = requireAuth(request);
  const claimId = String(request.data?.venueKey || '').trim();
  if (!claimId || claimId.length > 240) throw new HttpsError('invalid-argument', 'Mekan kimliği geçersiz.');
  const db = getFirestore();
  const ref = db.collection('business_claims').doc(claimId);
  const until = await db.runTransaction(async transaction => {
    const snap = await transaction.get(ref);
    const data = snap.data() || {};
    if (!snap.exists || data.status !== 'verified' || data.applicantUid !== uid) {
      throw new HttpsError('permission-denied', 'Doğrulanmış işletme sahibi gerekli.');
    }
    if (data.premiumTrialStartedAt) {
      throw new HttpsError('already-exists', 'Premium deneme hakkı daha önce kullanılmış.');
    }
    const trialUntil = Timestamp.fromMillis(Date.now() + PREMIUM_TRIAL_DAYS * 86400000);
    const update = {
      premiumTrialStatus: 'active',
      premiumTrialStartedAt: FieldValue.serverTimestamp(),
      premiumTrialUntil: trialUntil,
      billingRequired: false,
      updatedAt: FieldValue.serverTimestamp(),
    };
    transaction.set(ref, update, {merge: true});
    transaction.set(db.collection('business_venues').doc(claimId), update, {merge: true});
    return trialUntil;
  });
  return {started: true, premiumTrialUntilMs: until.toMillis(), days: PREMIUM_TRIAL_DAYS};
});
