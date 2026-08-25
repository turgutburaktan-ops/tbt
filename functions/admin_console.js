const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore} = require('firebase-admin/firestore');

function requireAdmin(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (request.auth.token?.admin !== true) {
    throw new HttpsError('permission-denied', 'Yönetici yetkisi gerekli.');
  }
  return request.auth.uid;
}

exports.getAdminBusinessClaims = onCall({region: 'europe-west1'}, async (request) => {
  requireAdmin(request);
  const db = getFirestore();
  const [claimsSnap, venuesSnap] = await Promise.all([
    db.collection('business_claims').limit(400).get(),
    db.collection('business_venues').limit(400).get(),
  ]);

  const byKey = new Map();
  for (const doc of claimsSnap.docs) {
    const d = doc.data() || {};
    const category = String(d.category || '').trim();
    const venueId = String(d.venueId || '').trim();
    const key = String(d.venueKey || (category && venueId ? `${category}:${venueId}` : doc.id));
    byKey.set(key, {
      id: doc.id,
      venueKey: key,
      source: 'claim',
      ...d,
    });
  }

  for (const doc of venuesSnap.docs) {
    const d = doc.data() || {};
    const key = doc.id;
    const existing = byKey.get(key) || {};
    const [categoryFromKey = '', venueIdFromKey = ''] = key.split(':');
    byKey.set(key, {
      id: existing.id || doc.id,
      venueKey: key,
      source: existing.source || 'venue',
      category: existing.category || d.category || categoryFromKey,
      venueId: existing.venueId || d.venueId || venueIdFromKey,
      venueName: existing.venueName || d.name || d.venueName || 'İşletme',
      legalName: existing.legalName || d.legalName || '',
      businessEmail: existing.businessEmail || d.businessEmail || d.email || '',
      businessPhone: existing.businessPhone || d.businessPhone || d.phone || '',
      applicantUid: existing.applicantUid || d.ownerUid || '',
      status: existing.status || (d.verified === true ? 'verified' : 'listed'),
      verified: d.verified === true || existing.status === 'verified',
      updatedAt: existing.updatedAt || d.updatedAt || d.createdAt || null,
      createdAt: existing.createdAt || d.createdAt || null,
      ...existing,
    });
  }

  const items = [...byKey.values()];
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
  const errorSnap = await db
    .collection('app_errors')
    .orderBy('createdAt', 'desc')
    .limit(20)
    .get()
    .catch(() => ({docs: []}));
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
