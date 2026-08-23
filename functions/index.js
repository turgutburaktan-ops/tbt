const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');

initializeApp();

const EVENT_TYPES = new Set([
  'event_join',
  'social_event_join',
  'event_cancelled',
  'social_event_cancelled',
  'event_updated',
  'event_time_changed',
  'community_event',
  'event_memory',
  'campus_digest',
]);

function notificationRef(db, userId, id) {
  return db.collection('users').doc(userId).collection('notifications').doc(id);
}

exports.pushOnNotificationCreated = onDocumentCreated(
  'users/{userId}/notifications/{notificationId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = event.params.userId;
    const db = getFirestore();
    const tokensSnap = await db.collection('users').doc(userId).collection('push_tokens').get();
    const tokens = tokensSnap.docs
      .map((doc) => (doc.data().token || '').trim())
      .filter(Boolean);
    if (!tokens.length) return;

    const sourceId = data.sourceId ? String(data.sourceId) : '';
    const actorId = data.actorId ? String(data.actorId) : '';
    const type = data.type ? String(data.type) : 'general';
    const message = {
      tokens,
      notification: {
        title: String(data.title || 'TBT'),
        body: String(data.body || 'Yeni bir bildirimin var.'),
      },
      data: {
        type,
        sourceId,
        actorId,
        eventId: EVENT_TYPES.has(type) ? sourceId : '',
        communityId: type === 'community' ? sourceId : '',
      },
      android: {
        priority: 'high',
        notification: {sound: 'default'},
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const result = await getMessaging().sendEachForMulticast(message);
    const stale = [];
    result.responses.forEach((response, index) => {
      const code = response.error?.code || '';
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        stale.push(tokens[index]);
      }
    });

    await Promise.all(
      stale.map((token) =>
        db.collection('users').doc(userId).collection('push_tokens').doc(token).delete()
      )
    );
  }
);

exports.notifyEventStatusChanges = onDocumentUpdated(
  'social_events/{eventId}',
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const eventId = event.params.eventId;
    const title = String(after.title || before.title || 'Etkinlik');
    const beforeStatus = String(before.status || 'open');
    const afterStatus = String(after.status || 'open');
    const beforeStartsAt = before.startsAt instanceof Timestamp ? before.startsAt.toMillis() : 0;
    const afterStartsAt = after.startsAt instanceof Timestamp ? after.startsAt.toMillis() : 0;

    let type = '';
    let pushTitle = '';
    let body = title;

    if (beforeStatus !== afterStatus && afterStatus === 'cancelled') {
      type = 'event_cancelled';
      pushTitle = 'Etkinlik iptal edildi';
    } else if (beforeStartsAt && afterStartsAt && beforeStartsAt !== afterStartsAt) {
      type = 'event_time_changed';
      pushTitle = 'Etkinlik saati değişti';
      const date = new Date(afterStartsAt);
      body = `${title} • ${new Intl.DateTimeFormat('tr-TR', {
        timeZone: 'Europe/Istanbul',
        day: '2-digit',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      }).format(date)}`;
    } else {
      return;
    }

    const db = getFirestore();
    const audience = new Set(
      (after.participantIds || before.participantIds || [])
        .map((id) => String(id || '').trim())
        .filter(Boolean)
    );

    try {
      const attendance = await db
        .collection('social_events')
        .doc(eventId)
        .collection('attendance')
        .get();
      for (const doc of attendance.docs) {
        const status = String(doc.data().status || '');
        if (status === 'going' || status === 'interested' || status === 'private') {
          audience.add(doc.id);
        }
      }
    } catch (_) {}

    const hostId = String(after.hostId || before.hostId || '');
    audience.delete(hostId);
    if (!audience.size) return;

    const changeKey = event.data.after.updateTime?.toMillis?.() || Date.now();
    const writes = [];
    for (const userId of audience) {
      const ref = notificationRef(db, userId, `event_${eventId}_${type}_${changeKey}`);
      writes.push(
        ref.set({
          type,
          title: pushTitle,
          body,
          sourceId: eventId,
          actorId: hostId || null,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        })
      );
    }
    await Promise.all(writes);
  }
);

exports.sendReengagementNotifications = onSchedule(
  {
    schedule: '0 19 * * *',
    timeZone: 'Europe/Istanbul',
    region: 'europe-west1',
  },
  async () => {
    const db = getFirestore();
    const now = Date.now();
    const cutoff = Timestamp.fromMillis(now - 48 * 60 * 60 * 1000);
    const usersSnap = await db
      .collection('users')
      .where('lastActiveAt', '<=', cutoff)
      .orderBy('lastActiveAt', 'asc')
      .limit(400)
      .get();

    if (usersSnap.empty) return;

    const dayKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Europe/Istanbul',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
      .format(new Date(now))
      .replaceAll('-', '');

    const writes = [];
    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data() || {};
      if (data.pushReengagementEnabled === false) continue;

      const lastActiveAt = data.lastActiveAt instanceof Timestamp
        ? data.lastActiveAt.toMillis()
        : 0;
      if (!lastActiveAt) continue;

      const inactiveDays = Math.max(2, Math.floor((now - lastActiveAt) / 86400000));
      let title = 'TBT’de yeni şeyler seni bekliyor';
      let body = 'Yeni fotoğraf noktalarına, paylaşımlara ve etkinliklere göz at.';

      if (inactiveDays >= 7) {
        title = 'Bir süredir yoksun 👀';
        body = 'Yeni çekim noktaları ve etkinlikler eklendi. TBT’ye dönüp keşfet.';
      } else if (inactiveDays >= 3) {
        title = 'Bugün keşfedecek yeni bir yer olabilir';
        body = 'Yakınındaki yeni çekim noktalarına ve etkinliklere göz at.';
      }

      const ref = notificationRef(db, userDoc.id, `reengagement_${dayKey}`);
      writes.push(
        ref.set(
          {
            type: 'reengagement',
            title,
            body,
            sourceId: null,
            actorId: null,
            read: false,
            smart: true,
            createdAt: FieldValue.serverTimestamp(),
          },
          {merge: false}
        )
      );
    }

    await Promise.all(writes);
  }
);

function levelForXp(xp) {
  if (xp >= 6000) return {level: 6, title: 'Türkiye Kaşifi'};
  if (xp >= 3000) return {level: 5, title: 'Usta Kaşif'};
  if (xp >= 1500) return {level: 4, title: 'Şehir Rehberi'};
  if (xp >= 600) return {level: 3, title: 'Fotoğraf Avcısı'};
  if (xp >= 200) return {level: 2, title: 'Kaşif'};
  return {level: 1, title: 'Gezgin'};
}

function periodKeys(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit'
  }).format(now);
  const dayKey = parts.replaceAll('-', '');
  const local = new Date(now.toLocaleString('en-US', {timeZone: 'Europe/Istanbul'}));
  const day = local.getDay() || 7;
  local.setDate(local.getDate() - day + 1);
  const weekKey = new Intl.DateTimeFormat('en-CA', {
    year: 'numeric', month: '2-digit', day: '2-digit'
  }).format(local).replaceAll('-', '');
  return {dayKey, weekKey};
}

async function awardXp({userId, points, action, sourceId, label}) {
  if (!userId || !sourceId || points <= 0) return;
  const db = getFirestore();
  const userRef = db.collection('users').doc(userId);
  const rewardRef = userRef.collection('xp_events').doc(`${action}_${sourceId}`);
  const {dayKey, weekKey} = periodKeys();

  await db.runTransaction(async (tx) => {
    const [rewardSnap, userSnap] = await Promise.all([tx.get(rewardRef), tx.get(userRef)]);
    if (rewardSnap.exists) return;
    const user = userSnap.data() || {};
    const oldXp = Number(user.xp || 0);
    const newXp = oldXp + points;
    const oldDailyKey = String(user.dailyXpKey || '');
    const oldWeeklyKey = String(user.weeklyXpKey || '');
    const dailyXp = (oldDailyKey === dayKey ? Number(user.dailyXp || 0) : 0) + points;
    const weeklyXp = (oldWeeklyKey === weekKey ? Number(user.weeklyXp || 0) : 0) + points;
    const dailyActions = oldDailyKey === dayKey ? {...(user.dailyActions || {})} : {};
    const weeklyActions = oldWeeklyKey === weekKey ? {...(user.weeklyActions || {})} : {};
    dailyActions[action] = Number(dailyActions[action] || 0) + 1;
    weeklyActions[action] = Number(weeklyActions[action] || 0) + 1;
    const rank = levelForXp(newXp);

    tx.set(userRef, {
      xp: newXp,
      level: rank.level,
      levelTitle: rank.title,
      dailyXp,
      dailyXpKey: dayKey,
      dailyActions,
      weeklyXp,
      weeklyXpKey: weekKey,
      weeklyActions,
      gamificationUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(rewardRef, {
      points, action, sourceId, label,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

exports.awardPostXp = onDocumentCreated('posts/{postId}', async (event) => {
  const data = event.data?.data() || {};
  if (String(data.sourceType || 'post') === 'event_memory') return;
  await awardXp({
    userId: String(data.userId || ''),
    points: 10,
    action: 'post',
    sourceId: event.params.postId,
    label: 'Paylaşım yaptı',
  });
});

exports.awardStoryXp = onDocumentCreated('stories/{storyId}', async (event) => {
  const data = event.data?.data() || {};
  await awardXp({
    userId: String(data.userId || data.ownerId || ''),
    points: 5,
    action: 'story',
    sourceId: event.params.storyId,
    label: 'Story paylaştı',
  });
});

exports.awardEventCreateXp = onDocumentCreated('social_events/{eventId}', async (event) => {
  const data = event.data?.data() || {};
  await awardXp({
    userId: String(data.hostId || ''),
    points: 50,
    action: 'event_create',
    sourceId: event.params.eventId,
    label: 'Etkinlik oluşturdu',
  });
});

exports.awardEventMemoryXp = onDocumentCreated('event_memories/{memoryId}', async (event) => {
  const data = event.data?.data() || {};
  await awardXp({
    userId: String(data.userId || ''),
    points: 20,
    action: 'event_memory',
    sourceId: event.params.memoryId,
    label: 'Etkinlik anısı ekledi',
  });
});

exports.awardEventJoinXp = onDocumentUpdated('social_events/{eventId}', async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const beforeIds = new Set((before.participantIds || []).map(String));
  const afterIds = new Set((after.participantIds || []).map(String));
  const hostId = String(after.hostId || before.hostId || '');
  const added = [...afterIds].filter((id) => id && id !== hostId && !beforeIds.has(id));
  await Promise.all(added.map((userId) => awardXp({
    userId,
    points: 15,
    action: 'event_join',
    sourceId: `${event.params.eventId}_${userId}`,
    label: 'Etkinliğe katıldı',
  })));
});

exports.awardFiftyLikesXp = onDocumentCreated('posts/{postId}/likes/{userId}', async (event) => {
  const db = getFirestore();
  const postRef = db.collection('posts').doc(event.params.postId);
  const [postSnap, likesSnap] = await Promise.all([
    postRef.get(),
    postRef.collection('likes').count().get(),
  ]);
  const count = likesSnap.data().count || 0;
  if (count < 50) return;
  const data = postSnap.data() || {};
  await awardXp({
    userId: String(data.userId || ''),
    points: 25,
    action: 'post_50_likes',
    sourceId: event.params.postId,
    label: 'Paylaşımı 50 beğeni aldı',
  });
});
