const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');

function clean(value, max = 300) {
  return String(value || '').trim().slice(0, max);
}

async function writeNotification(userId, id, payload) {
  if (!userId) return;
  await getFirestore()
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .doc(id)
    .set({
      ...payload,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
}

async function notifyFollowers(venueKey, notificationId, payload) {
  const db = getFirestore();
  const followers = await db
    .collection('business_venues')
    .doc(venueKey)
    .collection('followers')
    .limit(2000)
    .get();

  const docs = followers.docs;
  for (let offset = 0; offset < docs.length; offset += 400) {
    const batch = db.batch();
    for (const follower of docs.slice(offset, offset + 400)) {
      const ref = db.collection('users').doc(follower.id).collection('notifications').doc(notificationId);
      batch.set(ref, {
        ...payload,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    await batch.commit();
  }
}

exports.onBusinessCampaignPublished = onDocumentCreated(
  {region: 'europe-west1', document: 'business_venues/{venueKey}/campaigns/{campaignId}'},
  async (event) => {
    const data = event.data?.data() || {};
    if (data.active === false) return;
    const venueKey = event.params.venueKey;
    const campaignId = event.params.campaignId;
    const venue = await getFirestore().collection('business_venues').doc(venueKey).get();
    const venueName = clean(venue.data()?.venueName || 'Takip ettiğin işletme', 180);
    await notifyFollowers(venueKey, `business_campaign_${campaignId}`, {
      type: 'business_campaign',
      title: `${venueName} yeni bir kampanya yayınladı`,
      body: clean(data.title || data.description || 'Yeni kampanyaya göz at.', 220),
      sourceId: venueKey,
      businessVenueKey: venueKey,
      contentId: campaignId,
      actorId: venue.data()?.ownerUid || null,
    });
  }
);

exports.onBusinessProgramPublished = onDocumentCreated(
  {region: 'europe-west1', document: 'business_venues/{venueKey}/program/{programId}'},
  async (event) => {
    const data = event.data?.data() || {};
    if (data.active === false) return;
    const venueKey = event.params.venueKey;
    const programId = event.params.programId;
    const venue = await getFirestore().collection('business_venues').doc(venueKey).get();
    const venueName = clean(venue.data()?.venueName || 'Takip ettiğin işletme', 180);
    await notifyFollowers(venueKey, `business_event_${programId}`, {
      type: 'business_event',
      title: `${venueName} yeni bir etkinlik yayınladı`,
      body: clean(data.title || data.description || 'Yeni etkinliğe göz at.', 220),
      sourceId: venueKey,
      businessVenueKey: venueKey,
      contentId: programId,
      actorId: venue.data()?.ownerUid || null,
    });
  }
);

exports.onBusinessReservationCreated = onDocumentCreated(
  {region: 'europe-west1', document: 'business_venues/{venueKey}/reservations/{reservationId}'},
  async (event) => {
    const data = event.data?.data() || {};
    const venueKey = event.params.venueKey;
    const reservationId = event.params.reservationId;
    const venue = await getFirestore().collection('business_venues').doc(venueKey).get();
    const ownerUid = clean(venue.data()?.ownerUid, 180);
    if (!ownerUid) return;
    await writeNotification(ownerUid, `business_reservation_${reservationId}`, {
      type: 'business_reservation',
      title: 'Yeni rezervasyon talebi',
      body: `${Number(data.partySize || 0)} kişilik yeni rezervasyon talebi geldi.`,
      sourceId: venueKey,
      businessVenueKey: venueKey,
      contentId: reservationId,
      actorId: clean(data.userUid, 180) || null,
    });
  }
);

exports.onBusinessReservationUpdated = onDocumentUpdated(
  {region: 'europe-west1', document: 'business_venues/{venueKey}/reservations/{reservationId}'},
  async (event) => {
    const before = event.data?.before.data() || {};
    const after = event.data?.after.data() || {};
    if (before.status === after.status || !['accepted', 'rejected'].includes(after.status)) return;
    const userUid = clean(after.userUid, 180);
    if (!userUid) return;
    const venueKey = event.params.venueKey;
    const reservationId = event.params.reservationId;
    const venue = await getFirestore().collection('business_venues').doc(venueKey).get();
    const venueName = clean(venue.data()?.venueName || 'İşletme', 180);
    const accepted = after.status === 'accepted';
    await writeNotification(userUid, `business_reservation_response_${reservationId}_${after.status}`, {
      type: 'business_reservation_response',
      title: accepted ? 'Rezervasyonun onaylandı' : 'Rezervasyon talebin sonuçlandı',
      body: accepted
        ? `${venueName} rezervasyon talebini onayladı.`
        : `${venueName} rezervasyon talebini şu anda kabul edemedi.`,
      sourceId: venueKey,
      businessVenueKey: venueKey,
      contentId: reservationId,
      actorId: venue.data()?.ownerUid || null,
    });
  }
);
