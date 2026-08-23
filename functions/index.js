const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');

initializeApp();

exports.pushOnNotificationCreated = onDocumentCreated(
  'users/{userId}/notifications/{notificationId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const userId = event.params.userId;
    const db = getFirestore();
    const tokensSnap = await db.collection('users').doc(userId).collection('push_tokens').get();
    const tokens = tokensSnap.docs.map((doc) => (doc.data().token || '').trim()).filter(Boolean);
    if (!tokens.length) return;
    const sourceId = data.sourceId ? String(data.sourceId) : '';
    const actorId = data.actorId ? String(data.actorId) : '';
    const type = data.type ? String(data.type) : 'general';
    const eventTypes = ['event_join','social_event_join','event_cancelled','social_event_cancelled','community_event','event_memory','campus_digest'];
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
        eventId: eventTypes.includes(type) ? sourceId : '',
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
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') stale.push(tokens[index]);
    });
    await Promise.all(stale.map((token) => db.collection('users').doc(userId).collection('push_tokens').doc(token).delete()));
  }
);
