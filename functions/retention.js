const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {pushPreferenceAllowed} = require('./notification_policy');

const HOUR = 60 * 60 * 1000;

function weeklyDigestCopy(postCount, eventCount) {
  if (postCount > 0 && eventCount > 0) {
    return {
      title: 'TBT’de bu hafta hareket var',
      body: `${postCount} yeni paylaşım ve ${eventCount} yaklaşan etkinlik seni bekliyor.`,
    };
  }
  if (postCount > 0) {
    return {
      title: 'TBT’de yeni paylaşımlar var',
      body: `Bu hafta ${postCount} yeni paylaşım geldi. Şimdi keşfet.`,
    };
  }
  return {
    title: 'Yaklaşan etkinlikleri kaçırma',
    body: `Önümüzdeki 7 günde ${eventCount} etkinlik var. Çevrende neler olduğuna göz at.`,
  };
}

exports.sendRetentionDigest = onSchedule(
  {region: 'europe-west1', schedule: '0 18 * * 0', timeZone: 'Europe/Istanbul'},
  async () => {
    const db = getFirestore();
    const now = Date.now();
    const recentCutoff = Timestamp.fromMillis(now - 7 * 24 * HOUR);
    const eventEnd = Timestamp.fromMillis(now + 7 * 24 * HOUR);

    const [postsSnap, eventsSnap] = await Promise.all([
      db.collection('posts').where('createdAt', '>=', recentCutoff).limit(200).get(),
      db.collection('social_events')
        .where('startsAt', '>=', Timestamp.fromMillis(now))
        .where('startsAt', '<=', eventEnd)
        .limit(120)
        .get(),
    ]);
    if (postsSnap.empty && eventsSnap.empty) return;

    const copy = weeklyDigestCopy(postsSnap.size, eventsSnap.size);
    const weekKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date(now)).replaceAll('-', '');
    const users = await db.collection('users').limit(1000).get();
    const candidates = users.docs.filter((user) => {
      const data = user.data() || {};
      if (!pushPreferenceAllowed(data, 'weekly_digest')) return false;
      const lastActive = data.lastActiveAt instanceof Timestamp ? data.lastActiveAt.toMillis() : 0;
      const lastSent = data.lastReengagementNotificationAt instanceof Timestamp
        ? data.lastReengagementNotificationAt.toMillis()
        : 0;
      return (!lastActive || now - lastActive >= 36 * HOUR) &&
        (!lastSent || now - lastSent >= 72 * HOUR);
    });

    for (let offset = 0; offset < candidates.length; offset += 200) {
      const batch = db.batch();
      for (const user of candidates.slice(offset, offset + 200)) {
        batch.set(user.ref.collection('notifications').doc(`weekly_digest_${weekKey}`), {
          type: 'weekly_digest',
          title: copy.title,
          body: copy.body,
          sourceId: null,
          actorId: null,
          read: false,
          smart: true,
          createdAt: FieldValue.serverTimestamp(),
        }, {merge: false});
        batch.set(user.ref, {
          lastRetentionPushAt: FieldValue.serverTimestamp(),
          lastReengagementNotificationAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      await batch.commit();
    }
  },
);

exports._test = {weeklyDigestCopy};
