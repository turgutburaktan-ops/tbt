const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore} = require('firebase-admin/firestore');

function requireAdmin(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (request.auth.token?.admin !== true) throw new HttpsError('permission-denied', 'Yönetici yetkisi gerekli.');
  return request.auth.uid;
}

exports.getAdminBusinessClaims = onCall({region: 'europe-west1'}, async (request) => {
  requireAdmin(request);
  const db = getFirestore();
  const snap = await db.collection('business_claims').limit(400).get();
  const items = snap.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  items.sort((a, b) => {
    const av = a.updatedAt?.toMillis?.() || a.createdAt?.toMillis?.() || 0;
    const bv = b.updatedAt?.toMillis?.() || b.createdAt?.toMillis?.() || 0;
    return bv - av;
  });
  return {items};
});

exports.getAdminInsights = onCall({region: 'europe-west1'}, async (request) => {
  requireAdmin(request);
  const db = getFirestore();
  const count = async (query) => (await query.count().get()).data().count || 0;
  const [reports, deletes, analytics, errors, trustReports] = await Promise.all([
    count(db.collection('moderation_reports').where('status', '==', 'open')).catch(() => 0),
    count(db.collection('account_delete_requests').where('status', '==', 'requested')).catch(() => 0),
    count(db.collection('analytics_events')).catch(() => 0),
    count(db.collection('app_errors')).catch(() => 0),
    count(db.collectionGroup('trust_reports').where('status', '==', 'open')).catch(() => 0),
  ]);
  const errorSnap = await db.collection('app_errors').orderBy('createdAt', 'desc').limit(20).get().catch(() => ({docs: []}));
  return {
    counts: {
      openReports: reports,
      deleteRequests: deletes,
      analyticsEvents: analytics,
      appErrors: errors,
      trustReports,
    },
    errors: errorSnap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
  };
});
