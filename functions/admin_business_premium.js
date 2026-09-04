const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

function requireAdmin(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (request.auth.token.admin !== true || String(request.auth.token.email || '').toLowerCase() !== 'turgutburaktan@gmail.com') {
    throw new HttpsError('permission-denied', 'Bu panel yalnız tanımlı yönetici hesabına açıktır.');
  }
  return request.auth.uid;
}

exports.adminSetBusinessPremium = onCall({region: 'europe-west1'}, async (request) => {
  const adminUid = requireAdmin(request);
  const venueKey = String(request.data?.venueKey || '').trim();
  const enabled = request.data?.enabled === true;
  const days = Math.min(3650, Math.max(1, Number(request.data?.days || 90)));
  const note = String(request.data?.note || '').trim().slice(0, 300);
  if (!venueKey || venueKey.length > 240) throw new HttpsError('invalid-argument', 'İşletme kimliği geçersiz.');

  const db = getFirestore();
  const claimRef = db.collection('business_claims').doc(venueKey);
  const venueRef = db.collection('business_venues').doc(venueKey);
  const claim = await claimRef.get();
  if (!claim.exists || claim.data()?.status !== 'verified') {
    throw new HttpsError('failed-precondition', 'Yalnız doğrulanmış işletmelere premium verilebilir.');
  }

  if (!enabled) {
    const data = claim.data() || {};
    const now = Date.now();
    const earlyUntil = data.earlyAccessUntil instanceof Timestamp ? data.earlyAccessUntil.toMillis() : 0;
    const paidActive = data.subscriptionStatus === 'active';
    const earlyActive = data.earlyAccessStatus === 'active' && earlyUntil > now;
    const fallbackEntitled = paidActive || earlyActive;
    const clear = {
      adminPremiumStatus: 'inactive',
      adminPremiumUntil: null,
      adminPremiumNote: note,
      premiumEntitled: fallbackEntitled,
      premiumReason: paidActive ? 'paid_subscription' : earlyActive ? 'verified_early_business' : 'none',
      plan: paidActive ? String(data.subscriptionPlan || 'business_pro') : earlyActive ? 'early_business_premium' : 'free',
      billingRequired: paidActive,
      premiumUpdatedAt: FieldValue.serverTimestamp(),
      premiumUpdatedBy: adminUid,
    };
    await Promise.all([claimRef.set(clear, {merge: true}), venueRef.set(clear, {merge: true})]);
    return {enabled: false, fallbackEntitled};
  }

  const until = Timestamp.fromMillis(Date.now() + days * 86400000);
  const grant = {
    adminPremiumStatus: 'active',
    adminPremiumUntil: until,
    adminPremiumNote: note,
    premiumEntitled: true,
    premiumReason: 'admin_grant',
    plan: 'business_pro',
    billingRequired: false,
    premiumUpdatedAt: FieldValue.serverTimestamp(),
    premiumUpdatedBy: adminUid,
  };
  await Promise.all([claimRef.set(grant, {merge: true}), venueRef.set(grant, {merge: true})]);
  return {enabled: true, untilMs: until.toMillis()};
});
