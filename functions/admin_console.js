const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');

function requireAdmin(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (String(request.auth.token?.email || '').toLowerCase() !== 'turgutburaktan@gmail.com') {
    throw new HttpsError('permission-denied', 'Bu panel yalnız tanımlı yönetici hesabına açıktır.');
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
  const now = Date.now();
  const since24h = Timestamp.fromMillis(now - 24 * 60 * 60 * 1000);
  const since7d = Timestamp.fromMillis(now - 7 * 24 * 60 * 60 * 1000);
  const since30d = Timestamp.fromMillis(now - 30 * 24 * 60 * 60 * 1000);
  const count = async (query) => (await query.count().get()).data().count || 0;
  const safeCount = (query) => count(query).catch(() => 0);

  const countEntries = {
    totalUsers: db.collection('users'),
    newUsers24h: db.collection('users').where('createdAt', '>=', since24h),
    newUsers7d: db.collection('users').where('createdAt', '>=', since7d),
    newUsers30d: db.collection('users').where('createdAt', '>=', since30d),
    activeUsers7d: db.collection('users').where('lastActiveAt', '>=', since7d),
    activeUsers30d: db.collection('users').where('lastActiveAt', '>=', since30d),
    posts: db.collection('posts'),
    stories: db.collection('stories'),
    comments: db.collectionGroup('comments'),
    events: db.collection('social_events'),
    upcomingEvents: db.collection('social_events').where('startsAt', '>=', Timestamp.now()),
    verifiedBusinesses: db.collection('business_venues').where('verified', '==', true),
    pendingBusinessClaims: db.collection('business_claims').where('status', '==', 'pending_review'),
    openReports: db.collection('moderation_reports').where('status', '==', 'open'),
    deleteRequests: db.collection('account_delete_requests').where('status', '==', 'requested'),
    analyticsEvents: db.collection('analytics_events'),
    appErrors: db.collection('app_errors'),
    trustReports: db.collectionGroup('trust_reports').where('status', '==', 'open'),
  };
  const entries = Object.entries(countEntries);
  const values = await Promise.all(entries.map(([, query]) => safeCount(query)));
  const counts = Object.fromEntries(entries.map(([key], index) => [key, values[index]]));

  const [recentUsersSnap, topPostsSnap, errorSnap] = await Promise.all([
    db.collection('users').orderBy('createdAt', 'desc').limit(12).get().catch(() => ({docs: []})),
    db.collection('posts').orderBy('likesCount', 'desc').limit(8).get().catch(() => ({docs: []})),
    db.collection('app_errors').orderBy('createdAt', 'desc').limit(20).get().catch(() => ({docs: []})),
  ]);

  const recentUsers = recentUsersSnap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      displayName: String(d.displayName || d.name || d.username || 'TBT kullanıcısı'),
      username: String(d.username || ''),
      email: String(d.email || ''),
      photoURL: String(d.photoURL || d.photoUrl || ''),
      createdAt: d.createdAt || null,
      lastActiveAt: d.lastActiveAt || null,
    };
  });
  const topPosts = topPostsSnap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      userName: String(d.userName || 'TBT kullanıcısı'),
      caption: String(d.caption || '').slice(0, 180),
      spotName: String(d.spotName || ''),
      imageUrl: String(d.imageUrl || d.thumbnailUrl || ''),
      likesCount: Number(d.likesCount || 0),
      commentsCount: Number(d.commentsCount || 0),
      createdAt: d.createdAt || null,
    };
  });

  return {
    generatedAtMs: now,
    counts,
    recentUsers,
    topPosts,
    errors: errorSnap.docs.map((doc) => ({id: doc.id, ...doc.data()})),
  };
});

exports.sendAdminBroadcast = onCall({region: 'europe-west1'}, async (request) => {
  const adminUid = requireAdmin(request);
  const title = String(request.data?.title || '').trim().slice(0, 100);
  const body = String(request.data?.body || '').trim().slice(0, 600);
  if (!title || !body) {
    throw new HttpsError('invalid-argument', 'Başlık ve mesaj zorunludur.');
  }
  const db = getFirestore();
  const users = await db.collection('users').select().get();
  const writer = db.bulkWriter();
  const broadcastId = db.collection('admin_broadcasts').doc().id;
  for (const user of users.docs) {
    writer.set(user.ref.collection('notifications').doc(`broadcast_${broadcastId}`), {
      type: 'tbt_broadcast',
      title,
      body,
      sourceId: broadcastId,
      actorId: adminUid,
      senderName: 'TBT',
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  writer.set(db.collection('admin_broadcasts').doc(broadcastId), {
    title,
    body,
    recipientCount: users.size,
    sentBy: adminUid,
    createdAt: FieldValue.serverTimestamp(),
  });
  await writer.close();
  return {ok: true, recipientCount: users.size};
});

exports.adminDeleteVenue = onCall({region: 'europe-west1'}, async (request) => {
  const adminUid = requireAdmin(request);
  const collection = String(request.data?.collection || '').trim();
  const id = String(request.data?.id || '').trim();
  if (!['photo_spots', 'business_venues'].includes(collection) || !id) {
    throw new HttpsError('invalid-argument', 'Geçersiz mekan kaydı.');
  }
  const db = getFirestore();
  const ref = db.collection(collection).doc(id);
  const snapshot = await ref.get();
  if (!snapshot.exists) throw new HttpsError('not-found', 'Mekan bulunamadı.');
  await ref.delete();
  await db.collection('admin_audit_logs').add({
    action: 'venue_delete',
    collection,
    documentId: id,
    name: String(snapshot.data()?.name || snapshot.data()?.venueName || ''),
    adminUid,
    createdAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});
