const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {withAccountLifecycle} = require('./account_lifecycle_guard');

function requireUser(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return uid;
}

// Do not release the per-account lease while sibling writes still run.
async function settleAll(tasks) {
  const outcomes = await Promise.allSettled(tasks);
  const failure = outcomes.find(outcome => outcome.status === 'rejected');
  if (failure) throw failure.reason;
  return outcomes.map(outcome => outcome.value);
}

async function deleteQuery(db, query) {
  let deleted = 0;
  while (true) {
    const snapshot = await query.limit(200).get();
    if (snapshot.empty) return deleted;
    await settleAll(snapshot.docs.map((doc) => db.recursiveDelete(doc.ref)));
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
    return withAccountLifecycle({db, auth: getAuth(), uid, operation: 'freeze'}, async () => {
      await settleAll(
        ownedContent.map(([collection, field]) =>
          updateQuery(db, db.collection(collection).where(field, '==', uid), {
            accountFrozen: true,
            accountFrozenAt: FieldValue.serverTimestamp(),
          })
        )
      );
      await db.collection('account_delete_requests').doc(uid).delete().catch(() => {});
      return {ok: true, status: 'frozen'};
    });
  }
);

exports.unfreezeAccount = onCall(
  {region: 'europe-west1', timeoutSeconds: 120},
  async (request) => {
    const uid = requireUser(request);
    const db = getFirestore();
    return withAccountLifecycle({db, auth: getAuth(), uid, operation: 'unfreeze'}, async (user) => {
      if (user.accountStatus !== 'frozen') return {ok: true, status: 'active'};

      await settleAll(
        ownedContent.map(([collection, field]) =>
          updateQuery(db, db.collection(collection).where(field, '==', uid), {
            accountFrozen: FieldValue.delete(),
            accountFrozenAt: FieldValue.delete(),
          })
        )
      );
      return {ok: true, status: 'active'};
    });
  }
);

exports.deleteAccountNow = onCall(
  {region: 'europe-west1', timeoutSeconds: 540, memory: '1GiB'},
  async (request) => {
    const uid = requireUser(request);
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const authTime = Number(request.auth.token?.auth_time || 0);
    if (!Number.isFinite(authTime) || authTime <= 0 || Date.now()/1000 - authTime > 300 || authTime > Date.now()/1000 + 60) {
      throw new HttpsError('failed-precondition', 'Hesabını silmek için çıkış yapıp yeniden giriş yapmalısın.', {reason:'recent-login-required'});
    }
    return withAccountLifecycle({db, auth: getAuth(), uid, operation: 'delete'}, async () => {
      // Cleanup must run even if a legacy client already removed the public profile.
      await db.collection('account_cleanup_jobs').doc(uid).set({status:'running',updatedAt:FieldValue.serverTimestamp()}, {merge:true});


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
        ['chat_private_photos', 'senderId'],
        ['activity_demands', 'userId'],
        ['event_tickets', 'userId'],
      ];
      const groupQueries = [
        ['comments', 'userId'],
        ['likes', 'userId'],
        ['tags', 'userId'],
        ['attendance', 'userId'],
        ['interactions', 'userId'],
        ['ratings', 'userId'],
        ['reviews', 'userId'],
        ['visits', 'userId'],
        ['helpful', 'userId'],
        ['messages', 'senderId'],
        ['reservations', 'userUid'],
        ['followers', 'userId'],
        ['followers', 'uid'],
        ['following', 'userId'],
        ['notifications', 'actorId'],
      ];

      await settleAll([
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

      const bucket=getStorage().bucket();
      // Fail closed: never delete Auth while private uploaded files remain.
      await bucket.deleteFiles({prefix: `users/${uid}/`, force: false});
      for (const prefix of ['private_chat/', 'e2ee_chat/', 'e2ee_route/', 'e2ee_event/', 'route_albums/', 'route_chat/', 'event_chat/']) {
        let query={prefix,maxResults:100,autoPaginate:false};
        while(query) {
          const [files,next]=await bucket.getFiles(query);
          for (const file of files) {
            const parts=file.name.split('/');
            if(parts.length===5 && parts[2]===uid) await file.delete({ignoreNotFound:true});
          }
          query=next;
        }
      }
      await db.recursiveDelete(db.collection('private_users').doc(uid));
      await settleAll(['creator_profiles', 'creator_stats', 'notification_reply_limits', 'e2ee_identities', 'e2ee_key_limits', 'e2ee_send_limits'].map(collection => db.recursiveDelete(db.collection(collection).doc(uid))));
      await db.recursiveDelete(userRef);
      await db.collection('account_delete_requests').doc(uid).delete().catch(() => {});
      await getAuth().deleteUser(uid).catch((error) => {
        if (error?.code !== 'auth/user-not-found') throw error;
    });
    await db.collection('account_cleanup_jobs').doc(uid).set({status:'completed',updatedAt:FieldValue.serverTimestamp()}, {merge:true});
    return {ok: true, status: 'deleted'};
    });
  }
);

