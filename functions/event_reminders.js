const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

const MINUTE = 60 * 1000;

function reminderWindow(now = Date.now()) {
  return {start: now + 50 * MINUTE, end: now + 70 * MINUTE};
}

function reminderAudience(event, attendance = []) {
  const ids = new Set([
    String(event.hostId || '').trim(),
    ...(event.participantIds || []).map((id) => String(id || '').trim()),
  ].filter(Boolean));
  for (const item of attendance) {
    const status = String(item.status || '').trim();
    if (status === 'going' || status === 'private') ids.add(String(item.id || '').trim());
  }
  ids.delete('');
  return [...ids];
}

function reminderCopy(event, startsAtMs) {
  const title = String(event.title || 'Etkinlik').trim().slice(0, 120);
  const time = new Intl.DateTimeFormat('tr-TR', {
    timeZone: 'Europe/Istanbul', hour: '2-digit', minute: '2-digit',
  }).format(new Date(startsAtMs));
  const place = String(event.locationLabel || event.spotName || '').trim();
  return {
    title: 'Etkinliğine 1 saat kaldı',
    body: `${title} • ${time}${place ? ` • ${place}` : ''}`.slice(0, 220),
  };
}

async function createOnce(ref, data) {
  try {
    await ref.create(data);
    return true;
  } catch (error) {
    if (error?.code === 6 || error?.code === 'already-exists') return false;
    throw error;
  }
}

exports.sendEventReminders = onSchedule(
  {
    region: 'europe-west1',
    schedule: 'every 10 minutes',
    timeZone: 'Europe/Istanbul',
    retryCount: 3,
  },
  async () => {
    const db = getFirestore();
    const {start, end} = reminderWindow();
    const events = await db.collection('social_events')
      .where('startsAt', '>=', Timestamp.fromMillis(start))
      .where('startsAt', '<=', Timestamp.fromMillis(end))
      .orderBy('startsAt', 'asc')
      .limit(150)
      .get();

    for (const eventDoc of events.docs) {
      const event = eventDoc.data() || {};
      if (String(event.status || 'open') !== 'open') continue;
      const startsAtMs = event.startsAt instanceof Timestamp ? event.startsAt.toMillis() : 0;
      if (!startsAtMs) continue;

      let attendance = [];
      try {
        const snapshot = await eventDoc.ref.collection('attendance').limit(2000).get();
        attendance = snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
      } catch (_) {}

      const audience = reminderAudience(event, attendance);
      const copy = reminderCopy(event, startsAtMs);
      for (let offset = 0; offset < audience.length; offset += 100) {
        await Promise.all(audience.slice(offset, offset + 100).map((userId) => {
          const ref = db.collection('users').doc(userId).collection('notifications')
            .doc(`event_reminder_60_${eventDoc.id}`);
          return createOnce(ref, {
            type: 'event_reminder',
            title: copy.title,
            body: copy.body,
            sourceId: eventDoc.id,
            eventId: eventDoc.id,
            actorId: String(event.hostId || '') || null,
            read: false,
            smart: true,
            createdAt: FieldValue.serverTimestamp(),
          });
        }));
      }
    }
  }
);

exports._test = {reminderWindow, reminderAudience, reminderCopy};
