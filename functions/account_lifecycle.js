const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');

function requireUser(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return uid;
}

async function deleteQuery(db, query) {
  let deleted = 0;
  while (true) {
    const snapshot = await query.limit(200).get();
    if (snapshot.empty) return deleted;
    await Promise.all(snapshot.docs.map((doc) => db.recursiveDelete(doc.ref)));
    deleted += snapshot.size;
  }
}

async function updateQuery(db, query, data) {
  let updated = 0;
  let last = null;
  while (true) {
    let page = query.orderBy('__name__').limit(400);
    if (last) page = page.startAfter(last);
    const snapshot = await page.get();
    if (snapshot.empty) return updated;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.set(doc.ref, data, {merge: true}));
    await batch.commit();
    updated += snapshot.size;
    last = snapshot.docs[snapshot.docs.length - 1];
  }
}

const ownedContent = [
  ['posts', 'userId'],
  ['stories', 'userId'],
  ['post_reposts', 'userId'],
  ['social_events', 'hostId'],
  ['event_memories', 'userId'],
  ['travel_plans', 'ownerId'],
  ['communities', 'ownerId'],
];

exports.freezeAccount = onCall(
  {region: 'europe-west1', timeoutSeconds: 120},
  async (request) => {
    const uid = requireUser(request);
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const user = await userRef.get();
    if (!user.exists) throw new HttpsError('not-found', 'Hesap bulunamadı.');

    await Promise.all(
      ownedContent.map(([collection, field]) =>
        updateQuery(db, db.collection(collection).where(field, '==', uid), {
          accountFrozen: true,
          accountFrozenAt: FieldValue.serverTimestamp(),
        })
      )
    );
    await userRef.set({
      accountStatus: 'frozen',
      frozenAt: FieldValue.serverTimestamp(),
      accountStatusUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await db.collection('account_delete_requests').doc(uid).delete().catch(() => {});
    return {ok: true, status: 'frozen'};
  }
);

exports.unfreezeAccount = onCall(
  {region: 'europe-west1', timeoutSeconds: 120},
  async (request) => {
    const uid = requireUser(request);
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const user = await userRef.get();
    if (!user.exists) throw new HttpsError('not-found', 'Hesap bulunamadı.');
    if (user.data()?.accountStatus !== 'frozen') return {ok: true, status: 'active'};

    await Promise.all(
      ownedContent.map(([collection, field]) =>
        updateQuery(db, db.collection(collection).where(field, '==', uid), {
          accountFrozen: FieldValue.delete(),
          accountFrozenAt: FieldValue.delete(),
        })
      )
    );
    await userRef.set({
      accountStatus: 'active',
      frozenAt: FieldValue.delete(),
      accountStatusUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {ok: true, status: 'active'};
  }
);

exports.deleteAccountNow = onCall(
  {region: 'europe-west1', timeoutSeconds: 540, memory: '1GiB'},
  async (request) => {
    const uid = requireUser(request);
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const user = await userRef.get();
    if (!user.exists) {
      await getAuth().deleteUser(uid).catch((error) => {
        if (error?.code !== 'auth/user-not-found') throw error;
      });
      return {ok: true, status: 'deleted'};
    }

    await userRef.set({
      accountStatus: 'deleting',
      accountStatusUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    const ownedQueries = [
      ...ownedContent,
      ['post_bookmarks', 'userId'],
      ['creator_referrals', 'userId'],
      ['creator_referrals', 'creatorId'],
      ['creator_metric_receipts', 'userId'],
      ['social_publish_limits', 'userId'],
      ['user_map_points', 'ownerId'],
      ['moderation_reports', 'reporterId'],
      ['reports', 'reporterId'],
      ['review_reports', 'reporterId'],
      ['music_submissions', 'submittedBy'],
      ['music_takedown_requests', 'reporterId'],
      ['spot_submissions', 'submittedBy'],
      ['business_venue_submissions', 'createdBy'],
      ['business_claims', 'applicantUid'],
      ['analytics_events', 'userId'],
      ['app_errors', 'userId'],
      ['reservation_disputes', 'userUid'],
    ];
    const groupQueries = [
      ['comments', 'userId'],
      ['likes', 'userId'],
      ['tags', 'userId'],
      ['attendance', 'userId'],
      ['interactions', 'userId'],
      ['ratings', 'userId'],
      ['helpful', 'userId'],
      ['messages', 'senderId'],
      ['reservations', 'userUid'],
      ['followers', 'userId'],
      ['followers', 'uid'],
      ['following', 'userId'],
      ['notifications', 'actorId'],
    ];

    await Promise.all([
      ...ownedQueries.map(([collection, field]) =>
        deleteQuery(db, db.collection(collection).where(field, '==', uid))
      ),
      ...groupQueries.map(([collection, field]) =>
        deleteQuery(db, db.collectionGroup(collection).where(field, '==', uid))
      ),
      deleteQuery(db, db.collection('usernames').where('uid', '==', uid)),
    ]);

    const ownedVenues = await db.collection('business_venues')
      .where('ownerUid', '==', uid).limit(200).get();
    if (!ownedVenues.empty) {
      const batch = db.batch();
      ownedVenues.docs.forEach((doc) => batch.set(doc.ref, {
        ownerUid: FieldValue.delete(),
        verified: false,
        accountOwnerDeleted: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}));
      await batch.commit();
    }

    await getStorage().bucket().deleteFiles({prefix: `users/${uid}/`, force: true})
      .catch((error) => console.error('Account storage cleanup failed', uid, error));
    await Promise.all(['creator_profiles', 'creator_stats', 'notification_reply_limits'].map(collection => db.recursiveDelete(db.collection(collection).doc(uid))));
    await db.recursiveDelete(userRef);
    await db.collection('account_delete_requests').doc(uid).delete().catch(() => {});
    await getAuth().deleteUser(uid).catch((error) => {
      if (error?.code !== 'auth/user-not-found') throw error;
    });
    return {ok: true, status: 'deleted'};
  }
);
