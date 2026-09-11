const {notificationPayload}=require('./push_payload');
const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {marketingPushAllowed} = require('./broadcast_policy');
const {preferenceKeyForType, pushPreferenceAllowed} = require('./notification_policy');
const {_awardReputation: awardReputation} = require('./reputation_system');

initializeApp();

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
    const userRef = db.collection('users').doc(userId);
    const user = await userRef.get();
    if (['message','group_message'].includes(data.type) && data.sourceId) {
      const preferences = await db.doc(`users/${userId}/chat_preferences/${data.sourceId}`).get();
      if (preferences.data()?.muted) {
        await event.data.ref.set({pushStatus: 'suppressed', pushReason: 'chat_muted'}, {merge: true});
        return;
      }
      const thread = (await db.doc(`chat_threads/${data.sourceId}`).get()).data();
      if (thread?.requestStatus === 'rejected') {
        await event.data.ref.set({pushStatus: 'suppressed', pushReason: 'request_rejected'}, {merge: true});
        return;
      }
      if (thread?.requestStatus === 'pending') {
        // Requests stay in the requests inbox without repeated push interruptions.
        await event.data.ref.set({pushStatus: 'suppressed', pushReason: 'request_pending'}, {merge: true});
        return;
      }
    }
    if (data.type === 'tbt_broadcast') {
      // Re-check consent at delivery time, not only when the queue was made.
      if (data.pushAllowed !== true || !/^[a-zA-Z0-9_-]{16,80}$/.test(data.sourceId || '')) return;
      const job = await db.collection('admin_broadcasts').doc(data.sourceId).get();
      if (!marketingPushAllowed(user.data()) || !job.exists ||
          job.data().sentBy !== data.actorId || job.data().title !== data.title ||
          job.data().body !== data.body || (job.data().imageUrl||'')!==(data.imageUrl||'')) return;
    }

    if (!pushPreferenceAllowed(user.data(), data.type)) {
      await event.data.ref.set({
        pushStatus: 'suppressed',
        pushReason: `preference_${preferenceKeyForType(data.type) || 'all'}`,
        pushProcessedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }

    const tokensSnap = await userRef.collection('push_tokens').get();
    const tokens = tokensSnap.docs
      .map((doc) => (doc.data().token || '').trim())
      .filter(Boolean);
    if (!tokens.length) {
      await event.data.ref.set({
        pushStatus: 'no_token',
        pushProcessedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (data.type === 'tbt_broadcast') {
        await db.collection('admin_broadcasts').doc(data.sourceId).set({
          noTokenRecipientCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      return;
    }

    const groups=[tokensSnap.docs.filter(d=>d.data().platform==='android'&&d.data().replyActions===1),tokensSnap.docs.filter(d=>!(d.data().platform==='android'&&d.data().replyActions===1))];
    const responses=[],sentTokens=[];
    for(let group=0;group<groups.length;group++){
      const list=groups[group].map(d=>(d.data().token||'').trim()).filter(Boolean);
      for(let offset=0;offset<list.length;offset+=500){
        const batch=list.slice(offset,offset+500);
        const result=await getMessaging().sendEachForMulticast({tokens:batch,...notificationPayload(data,{userId,notificationId:event.params.notificationId,modernAndroid:group===0})});
        responses.push(...result.responses);sentTokens.push(...batch);
      }
    }
    const result={responses};
    const stale = [];
    result.responses.forEach((response, index) => {
      const code = response.error?.code || '';
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        stale.push(sentTokens[index]);
      }
    });

    await Promise.all(
      stale.map((token) =>
        db.collection('users').doc(userId).collection('push_tokens').doc(token).delete()
      )
    );

    const pushSuccessCount = result.responses.filter((response) => response.success).length;
    const pushFailureCount = result.responses.length - pushSuccessCount;
    await event.data.ref.set({
      pushStatus: pushSuccessCount > 0 ? 'sent' : 'failed',
      pushSuccessCount,
      pushFailureCount,
      pushProcessedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (data.type === 'tbt_broadcast') {
      await db.collection('admin_broadcasts').doc(data.sourceId).set({
        pushSuccessCount: FieldValue.increment(pushSuccessCount),
        pushFailureCount: FieldValue.increment(pushFailureCount),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }
);

exports.trackNotificationOpened = onDocumentUpdated(
  'users/{userId}/notifications/{notificationId}',
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (before.read === true || after.read !== true || after.type !== 'tbt_broadcast') return;
    const broadcastId = String(after.sourceId || '');
    if (!/^[a-zA-Z0-9_-]{16,80}$/.test(broadcastId)) return;
    const db = getFirestore();
    const jobRef = db.collection('admin_broadcasts').doc(broadcastId);
    await db.runTransaction(async (tx) => {
      const job = await tx.get(jobRef);
      if (!job.exists) return;
      tx.set(jobRef, {
        openedRecipientCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      tx.set(event.data.after.ref, {
        openTrackedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
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
    const [usersSnap, eventsSnap] = await Promise.all([
      db.collection('users')
        .where('lastActiveAt', '<=', cutoff)
        .orderBy('lastActiveAt', 'asc')
        .limit(400)
        .get(),
      db.collection('social_events')
        .where('startsAt', '>=', Timestamp.fromMillis(now))
        .where('startsAt', '<=', Timestamp.fromMillis(now + 7 * 86400000))
        .orderBy('startsAt', 'asc')
        .limit(200)
        .get(),
    ]);

    if (usersSnap.empty) return;

    const dayKey = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Europe/Istanbul',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
      .format(new Date(now))
      .replaceAll('-', '');

    const eventByCity = new Map();
    for (const eventDoc of eventsSnap.docs) {
      const event = eventDoc.data() || {};
      if (String(event.status || 'open') !== 'open' ||
          String(event.visibility || 'public') !== 'public') continue;
      const city = String(event.city || '').trim().toLocaleLowerCase('tr-TR');
      if (city && !eventByCity.has(city)) eventByCity.set(city, {id: eventDoc.id, ...event});
    }

    const candidates = [];
    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data() || {};
      if (!pushPreferenceAllowed(data, 'reengagement')) continue;

      const lastActiveAt = data.lastActiveAt instanceof Timestamp
        ? data.lastActiveAt.toMillis()
        : 0;
      if (!lastActiveAt) continue;
      const lastSentAt = data.lastReengagementNotificationAt instanceof Timestamp
        ? data.lastReengagementNotificationAt.toMillis()
        : 0;
      if (lastSentAt && now - lastSentAt < 72 * 60 * 60 * 1000) continue;

      const inactiveDays = Math.max(2, Math.floor((now - lastActiveAt) / 86400000));
      let title = 'TBT’de yeni şeyler seni bekliyor';
      let body = 'Yeni fotoğraf noktalarına, paylaşımlara ve etkinliklere göz at.';
      let sourceId = null;
      let eventId = null;

      const city = String(data.city || '').trim();
      const cityEvent = eventByCity.get(city.toLocaleLowerCase('tr-TR'));
      if (cityEvent) {
        title = `${city}’da yaklaşan bir etkinlik var`;
        body = String(cityEvent.title || 'Etkinliğin ayrıntılarını görmek için dokun.').slice(0, 220);
        sourceId = cityEvent.id;
        eventId = cityEvent.id;
      }

      if (!cityEvent && inactiveDays >= 7) {
        title = 'Bir süredir yoksun 👀';
        body = 'Yeni çekim noktaları ve etkinlikler eklendi. TBT’ye dönüp keşfet.';
      } else if (!cityEvent && inactiveDays >= 3) {
        title = 'Bugün keşfedecek yeni bir yer olabilir';
        body = 'Yakınındaki yeni çekim noktalarına ve etkinliklere göz at.';
      }

      const ref = notificationRef(db, userDoc.id, `reengagement_${dayKey}`);
      candidates.push({userDoc, ref, title, body, sourceId, eventId});
    }

    for (let offset = 0; offset < candidates.length; offset += 200) {
      const batch = db.batch();
      for (const item of candidates.slice(offset, offset + 200)) {
        batch.set(item.ref, {
          type: 'reengagement',
          title: item.title,
          body: item.body,
          sourceId: item.sourceId,
          eventId: item.eventId,
          actorId: null,
          read: false,
          smart: true,
          createdAt: FieldValue.serverTimestamp(),
        }, {merge: false});
        batch.set(item.userDoc.ref, {
          lastReengagementNotificationAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      await batch.commit();
    }
  }
);

exports.awardPostXp = onDocumentCreated('posts/{postId}', async (event) => {
  const data = event.data?.data() || {};
  if (String(data.sourceType || 'post') === 'event_memory') return;
  const userId = String(data.userId || '');
  const postId = event.params.postId;
  const mediaType = String(data.mediaType || 'image');
  const awards = [awardReputation({
    userId, role: 'creator', points: mediaType === 'video' ? 8 : 5,
    action: 'post', sourceId: postId,
    label: mediaType === 'video' ? 'Özgün Reels paylaştı' : 'Özgün gönderi paylaştı',
    stat: 'creatorContent',
  })];
  const hasLocation = data.latitude != null && data.longitude != null &&
    Number.isFinite(Number(data.latitude)) && Number.isFinite(Number(data.longitude)) &&
    String(data.spotName || '').trim();
  if (hasLocation && !String(data.businessVenueKey || '').trim()) {
    awards.push(awardReputation({
      userId, role: 'explorer', points: 8, action: 'located_post', sourceId: postId,
      label: 'Konumlu gezi paylaşımı yaptı', stat: 'explorerLocatedPosts', city: data.city,
    }));
  }
  const venueKey = String(data.businessVenueKey || data.venueKey || '').trim();
  if (venueKey) {
    const venue = await getFirestore().doc(`business_venues/${venueKey}`).get();
    if (venue.exists) {
      awards.push(awardReputation({
        userId, role: 'gourmet', points: 7, action: 'gourmet_post', sourceId: postId,
        label: 'Mekândan fotoğraflı deneyim paylaştı',
        stat: ['gourmetVenueContributions', 'gourmetPhotoReviews'], venueKey,
      }));
    }
  }
  await Promise.all(awards);
});

async function countMusicUsage(trackId) {
  const clean = String(trackId || '').trim();
  if (!clean) return;
  await getFirestore().collection('music_usage').doc(clean).set({
    storyCount: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

exports.countStoryMusicLinked = onDocumentUpdated('stories/{storyId}', async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const beforeId = String(before.musicTrackId || '');
  const afterId = String(after.musicTrackId || '');
  if (afterId && afterId !== beforeId) await countMusicUsage(afterId);
});

exports.awardStoryXp = onDocumentCreated('stories/{storyId}', async (event) => {
  const data = event.data?.data() || {};
  if (String(data.sharedPostId || '').trim()) return;
  await Promise.all([
    awardReputation({
    userId: String(data.userId || data.ownerId || ''),
    role: 'creator',
    points: 3,
    action: 'story',
    sourceId: event.params.storyId,
      label: 'Özgün Story paylaştı',
      stat: 'creatorStories',
    }),
    countMusicUsage(data.musicTrackId),
  ]);
});

exports.awardEventCreateXp = onDocumentCreated('social_events/{eventId}', async (event) => {
  // Etkinlik oluşturmak tek başına puan vermez. Gerçekleştiği, etkinlik anısı
  // veya kullanılan bilet ile doğrulandığında Sosyal puanı kazanılır.
  return;
});

exports.awardEventMemoryXp = onDocumentCreated('event_memories/{memoryId}', async (event) => {
  const data = event.data?.data() || {};
  const db = getFirestore();
  const eventId = String(data.eventId || '');
  const eventSnap = eventId ? await db.doc(`social_events/${eventId}`).get() : null;
  const hostId = String(eventSnap?.data()?.hostId || '');
  const awards = [awardReputation({
    userId: String(data.userId || ''), role: 'social', points: 5,
    action: 'event_memory', sourceId: event.params.memoryId,
    label: 'Etkinlik anısı paylaştı', stat: 'socialMemories',
  })];
  if (hostId) awards.push(awardReputation({
    userId: hostId, role: 'social', points: 25,
    action: 'hosted_completed_event', sourceId: eventId,
    label: 'Gerçekleşen etkinlik düzenledi', stat: 'socialHostedCompleted',
  }));
  await Promise.all(awards);
});

exports.awardEventJoinXp = onDocumentUpdated('social_events/{eventId}', async (event) => {
  // Katıl düğmesi yalnız niyet belirtir. Puan, bilet/katılım doğrulandığında
  // awardVerifiedEventAttendance tarafından verilir.
  return;
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
  await awardReputation({
    userId: String(data.userId || ''),
    role: 'creator',
    points: 15,
    action: 'post_50_likes',
    sourceId: event.params.postId,
    label: 'Paylaşımı 50 beğeni aldı',
    stat: 'creatorQualityBonuses',
  });
});
