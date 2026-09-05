const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {isNamedAdmin} = require('./broadcast_policy');

function requireAdmin(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (!isNamedAdmin(request.auth)) {
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
  const title = String(request.data?.title || '').trim();
  const body = String(request.data?.body || '').trim();
  const requestId = String(request.data?.requestId || '');
  if (!title || title.length > 100 || !body || body.length > 600 ||
      !/^[a-zA-Z0-9_-]{16,80}$/.test(requestId)) {
    throw new HttpsError('invalid-argument', 'Başlık, mesaj ve geçerli gönderim kimliği zorunludur.');
  }
  const db = getFirestore();
  const ref = db.collection('admin_broadcasts').doc(requestId);
  return db.runTransaction(async tx => {
    const existing = await tx.get(ref);
    if (existing.exists) {
      const job = existing.data();
      if (job.sentBy !== adminUid || job.title !== title || job.body !== body) {
        throw new HttpsError('already-exists', 'Bu gönderim kimliği başka bir duyuruya ait.');
      }
      return {ok: true, broadcastId: ref.id, status: job.status, recipientCount: job.recipientCount};
    }
    tx.create(ref, {title, body, sentBy: adminUid, status: 'queued',
      recipientCount: 0, cursor: null, createdAt: FieldValue.serverTimestamp()});
    return {ok: true, broadcastId: ref.id, status: 'queued', recipientCount: 0};
  });
});

exports.adminDeleteVenue = onCall({region: 'europe-west1'}, async (request) => {
  const adminUid = requireAdmin(request);
  const collection = String(request.data?.collection || '').trim();
  const id = String(request.data?.id || '').trim();
  if (!['photo_spots', 'business_venues'].includes(collection) || !id || id.includes('/') || id.length > 500) {
    throw new HttpsError('invalid-argument', 'Geçersiz mekan kaydı.');
  }
  const db = getFirestore();
  const ref = db.collection(collection).doc(id);
  await db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) throw new HttpsError('not-found', 'Mekan bulunamadı.');
    // Keep the original record for recovery; child collections are not purged.
    tx.create(db.collection('admin_audit_logs').doc(), {
      action: 'venue_delete', collection, documentId: id,
      original: snapshot.data(), adminUid, createdAt: FieldValue.serverTimestamp(),
    });
    tx.delete(ref);
  });
  return {ok: true};
});
