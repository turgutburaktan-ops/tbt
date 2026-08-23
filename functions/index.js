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
