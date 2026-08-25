const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');

const HOUR = 60 * 60 * 1000;

exports.sendRetentionDigest = onSchedule(
  {region: 'europe-west1', schedule: 'every 6 hours', timeZone: 'Europe/Istanbul'},
  async () => {
    const db = getFirestore();
    const now = Date.now();
    const recentCutoff = Timestamp.fromMillis(now - 12 * HOUR);
    const eventEnd = Timestamp.fromMillis(now + 24 * HOUR);

    const [postsSnap, eventsSnap] = await Promise.all([
      db.collection('posts').where('createdAt', '>=', recentCutoff).limit(100).get(),
      db.collection('social_events').where('startsAt', '>=', Timestamp.fromMillis(now)).where('startsAt', '<=', eventEnd).limit(60).get(),
    ]);

    const postCount = postsSnap.size;
    const eventCount = eventsSnap.size;
    if (postCount === 0 && eventCount === 0) return;

    const usersSnap = await db.collection('users').limit(300).get();
    const messaging = getMessaging();

    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data() || {};
      const lastActive = data.lastActiveAt instanceof Timestamp ? data.lastActiveAt.toMillis() : 0;
      const lastPush = data.lastRetentionPushAt instanceof Timestamp ? data.lastRetentionPushAt.toMillis() : 0;
      if (lastActive && now - lastActive < 36 * HOUR) continue;
      if (lastPush && now - lastPush < 48 * HOUR) continue;
      if (data.retentionNotificationsEnabled === false) continue;

      const tokenSnap = await userDoc.ref.collection('push_tokens').limit(8).get();
      const tokens = tokenSnap.docs.map((d) => String(d.data().token || '')).filter(Boolean);
      if (!tokens.length) continue;

      let title = 'TBT’de bugün hareket var';
      let body = '';
      if (postCount > 0 && eventCount > 0) {
        body = `${postCount} yeni paylaşım ve ${eventCount} yaklaşan etkinlik seni bekliyor.`;
      } else if (postCount > 0) {
        body = `Son saatlerde ${postCount} yeni paylaşım geldi. Şu an neler oluyor, bak.`;
      } else {
        body = `Önümüzdeki 24 saatte ${eventCount} etkinlik var. Çevrende neler olduğuna göz at.`;
      }

      try {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {title, body},
          data: {type: 'retention', destination: 'today_tbt'},
        });
        await userDoc.ref.set({lastRetentionPushAt: FieldValue.serverTimestamp()}, {merge: true});
      } catch (_) {
        // One user's invalid token must not stop the digest for everyone else.
      }
    }
  },
);
