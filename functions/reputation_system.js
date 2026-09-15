const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');

const REGION = 'europe-west1';
const DAY = 24 * 60 * 60 * 1000;

const ROLE_DEFINITIONS = Object.freeze({
  creator: Object.freeze({label: 'TBT Creator', threshold: 500}),
  explorer: Object.freeze({label: 'TBT Kâşif', threshold: 400}),
  social: Object.freeze({label: 'TBT Sosyal', threshold: 350}),
  gourmet: Object.freeze({label: 'TBT Gurme', threshold: 400}),
});

const ACTION_DAILY_CAPS = Object.freeze({
  post: 3,
  story: 3,
  located_post: 3,
  route_publish: 2,
  event_memory: 2,
  gourmet_post: 2,
  gourmet_review: 2,
});

function normalizeRole(value) {
  const role = String(value || '').trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(ROLE_DEFINITIONS, role) ? role : '';
}

function numberMap(value) {
  const source = value && typeof value === 'object' ? value : {};
  const result = {};
  for (const role of Object.keys(ROLE_DEFINITIONS)) {
    result[role] = Math.max(0, Math.floor(Number(source[role] || 0)));
  }
  return result;
}

function objectMap(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? {...value} : {};
}

function timestampMs(value) {
  if (typeof value?.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number(value || 0);
}

function accountAgeDays(user, nowMs = Date.now()) {
  const createdAtMs = timestampMs(user?.createdAt);
  if (!createdAtMs) return 0;
  return Math.max(0, Math.floor((nowMs - createdAtMs) / DAY));
}

function earnedRequirements(role, scores, stats, user, nowMs) {
  if (scores[role] < ROLE_DEFINITIONS[role].threshold) return false;
  if (role === 'creator') {
    return Number(stats.creatorContent || 0) >= 25 && accountAgeDays(user, nowMs) >= 60;
  }
  if (role === 'explorer') {
    const cities = Array.isArray(stats.explorerCities) ? stats.explorerCities : [];
    return Number(stats.explorerApprovedSpots || 0) >= 10 &&
      Number(stats.explorerLocatedPosts || 0) >= 20 && cities.length >= 3;
  }
  if (role === 'social') {
    return Number(stats.socialHostedCompleted || 0) >= 5 &&
      Number(stats.socialAttendance || 0) >= 10;
  }
  const venues = Array.isArray(stats.gourmetVenues) ? stats.gourmetVenues : [];
  return venues.length >= 15 &&
    Number(stats.gourmetPhotoReviews || 0) >= 10;
}

function evaluateReputation(user = {}, reputation = {}, nowMs = Date.now()) {
  const scores = numberMap(reputation.scores);
  const stats = objectMap(reputation.stats);
  const previousRoles = {
    ...objectMap(user.accountTypes),
    ...objectMap(reputation.roles),
  };
  const roles = {};
  for (const role of Object.keys(ROLE_DEFINITIONS)) {
    const previous = objectMap(previousRoles[role]);
    const invited = previous.active === true && ['invite', 'admin', 'legacy_creator', 'founding'].includes(previous.source);
    const legacyCreator = role === 'creator' && user.isCreator === true;
    const earned = earnedRequirements(role, scores, stats, user, nowMs);
    const active = invited || legacyCreator || earned;
    const source = invited ? previous.source : legacyCreator ? (user.creatorTier === 'founding' ? 'founding' : 'legacy_creator') : earned ? 'earned' : '';
    roles[role] = {
      active,
      source,
      ...(active ? {grantedAt: previous.grantedAt || Timestamp.fromMillis(nowMs)} : {}),
      threshold: ROLE_DEFINITIONS[role].threshold,
      label: ROLE_DEFINITIONS[role].label,
    };
  }
  const total = Object.values(scores).reduce((sum, value) => sum + value, 0);
  const cleanAccount = user.banned !== true && user.disabled !== true &&
    !['frozen', 'deleted', 'deleting'].includes(String(user.accountStatus || ''));
  const domainsWithPoints = Object.values(scores).filter((value) => value > 0).length;
  const verified = total >= 1000 && accountAgeDays(user, nowMs) >= 90 &&
    user.phoneVerified === true && user.reputationEmailVerified === true &&
    domainsWithPoints >= 2 && cleanAccount;
  const ambassador = verified && Object.values(roles).every((role) => role.active === true);
  return {
    version: 2,
    scores,
    stats,
    roles,
    total,
    verified,
    ambassador,
    updatedAt: Timestamp.fromMillis(nowMs),
  };
}

function dayKey(nowMs) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date(nowMs));
}

function appendUnique(values, item, limit = 100) {
  const clean = String(item || '').trim().toLowerCase();
  const result = Array.isArray(values) ? values.map(String) : [];
  if (clean && !result.includes(clean)) result.push(clean);
  return result.slice(-limit);
}

function notificationForNewRoles(db, userId, before, after, now) {
  const writes = [];
  for (const role of Object.keys(ROLE_DEFINITIONS)) {
    if (before?.[role]?.active === true || after[role]?.active !== true) continue;
    const id = `reputation_role_${role}`;
    writes.push({
      ref: db.doc(`users/${userId}/notifications/${id}`),
      data: {
        type: 'reputation_role',
        role,
        title: `${ROLE_DEFINITIONS[role].label} hesabın açıldı`,
        body: 'Katkıların yeni hesap türünü kazandırdı. Profilinden ayrıntıları görebilirsin.',
        actorId: null,
        read: false,
        createdAt: now,
      },
    });
  }
  return writes;
}

async function awardReputation({userId, role, points, action, sourceId, label, stat, city, venueKey, db = getFirestore(), nowMs = Date.now()}) {
  role = normalizeRole(role);
  points = Math.max(0, Math.floor(Number(points || 0)));
  if (!userId || !role || !action || !sourceId || points <= 0) return {awarded: false, reason: 'invalid'};
  const userRef = db.doc(`users/${userId}`);
  const receiptRef = db.doc(`reputation_events/${action}_${sourceId}`);
  return db.runTransaction(async (tx) => {
    const [receipt, userSnap] = await Promise.all([tx.get(receiptRef), tx.get(userRef)]);
    if (receipt.exists) return {awarded: false, reason: 'duplicate'};
    if (!userSnap.exists) return {awarded: false, reason: 'user_missing'};
    const user = userSnap.data() || {};
    if (user.banned === true || user.disabled === true || ['frozen', 'deleted', 'deleting'].includes(String(user.accountStatus || ''))) {
      return {awarded: false, reason: 'account_inactive'};
    }
    const current = objectMap(user.reputation);
    const daily = objectMap(current.daily);
    const today = dayKey(nowMs);
    const dailyCounts = daily.day === today ? objectMap(daily.counts) : {};
    const cap = ACTION_DAILY_CAPS[action];
    if (cap && Number(dailyCounts[action] || 0) >= cap) {
      tx.create(receiptRef, {userId, role, points: 0, action, sourceId, label, suppressed: 'daily_cap', createdAt: Timestamp.fromMillis(nowMs)});
      return {awarded: false, reason: 'daily_cap'};
    }
    const scores = numberMap(current.scores);
    const stats = objectMap(current.stats);
    scores[role] += points;
    const statNames = Array.isArray(stat) ? stat : stat ? [stat] : [];
    for (const statName of statNames) {
      stats[statName] = Math.max(0, Number(stats[statName] || 0)) + 1;
    }
    if (city) stats.explorerCities = appendUnique(stats.explorerCities, city, 81);
    if (venueKey) stats.gourmetVenues = appendUnique(stats.gourmetVenues, venueKey, 200);
    dailyCounts[action] = Number(dailyCounts[action] || 0) + 1;
    const next = evaluateReputation(user, {...current, scores, stats}, nowMs);
    next.daily = {day: today, counts: dailyCounts};
    const now = Timestamp.fromMillis(nowMs);
    tx.set(userRef, {
      reputation: next,
      reputationTotal: next.total,
      accountTypes: next.roles,
      tbtVerified: next.verified,
      tbtAmbassador: next.ambassador,
      ...(next.roles.creator.active ? {isCreator: true, profileType: user.profileType === 'personal' || !user.profileType ? 'creator' : user.profileType} : {}),
      reputationUpdatedAt: now,
    }, {merge: true});
    tx.create(receiptRef, {userId, role, points, action, sourceId, label, createdAt: now});
    for (const write of notificationForNewRoles(db, userId, current.roles, next.roles, now)) {
      tx.set(write.ref, write.data, {merge: false});
    }
    return {awarded: true, role, points, total: next.total, roles: next.roles};
  });
}

function grantInvitedRole(user, role, inviteCode, nowMs = Date.now()) {
  role = normalizeRole(role);
  if (!role) throw new Error('invalid role');
  const current = objectMap(user.reputation);
  const roles = objectMap(current.roles);
  roles[role] = {
    active: true,
    source: 'invite',
    grantedAt: Timestamp.fromMillis(nowMs),
    threshold: ROLE_DEFINITIONS[role].threshold,
    label: ROLE_DEFINITIONS[role].label,
  };
  return evaluateReputation(user, {...current, roles}, nowMs);
}

exports.getMyReputation = onCall({region: REGION}, async (request) => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  const db = getFirestore();
  const ref = db.doc(`users/${request.auth.uid}`);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('failed-precondition', 'Önce TBT profilini oluştur.');
  const user = {...(snap.data() || {}), reputationEmailVerified: request.auth.token?.email_verified === true};
  const reputation = evaluateReputation(user, user.reputation || {});
  await ref.set({
    reputation,
    reputationTotal: reputation.total,
    accountTypes: reputation.roles,
    tbtVerified: reputation.verified,
    tbtAmbassador: reputation.ambassador,
    reputationEmailVerified: request.auth.token?.email_verified === true,
    ...(reputation.roles.creator.active ? {
      isCreator: true,
      profileType: user.profileType === 'personal' || !user.profileType
        ? 'creator' : user.profileType,
    } : {}),
    reputationUpdatedAt: Timestamp.now(),
  }, {merge: true});
  return reputation;
});

exports.awardApprovedSpotReputation = onDocumentUpdated({region: REGION, document: 'spot_submissions/{submissionId}'}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (before.status === 'approved' || after.status !== 'approved') return;
  await awardReputation({
    userId: String(after.submittedBy || ''), role: 'explorer', points: 30,
    action: 'approved_spot', sourceId: event.params.submissionId,
    label: 'Gezilecek yer önerisi onaylandı', stat: 'explorerApprovedSpots', city: after.city,
  });
});

exports.awardPublishedRouteReputation = onDocumentCreated({region: REGION, document: 'travel_plans/{planId}'}, async (event) => {
  const data = event.data?.data() || {};
  if (data.isPublic !== true) return;
  await awardReputation({
    userId: String(data.ownerId || ''), role: 'explorer', points: 10,
    action: 'route_publish', sourceId: event.params.planId,
    label: 'Herkese açık rota yayınladı', stat: 'explorerRoutes', city: data.city,
  });
});

exports.awardVerifiedEventAttendance = onDocumentUpdated({region: REGION, document: 'event_tickets/{ticketId}'}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (before.status === 'used' || after.status !== 'used') return;
  await awardReputation({
    userId: String(after.userId || ''), role: 'social', points: 10,
    action: 'verified_event_attendance', sourceId: event.params.ticketId,
    label: 'Etkinliğe katılımı doğrulandı', stat: 'socialAttendance',
  });
});

exports.awardGourmetReviewReputation = onDocumentCreated({region: REGION, document: 'venue_ratings/{venueKey}/ratings/{userId}'}, async (event) => {
  const data = event.data?.data() || {};
  if (String(data.comment || '').trim().length < 20) return;
  const venue = await getFirestore().doc(`business_venues/${event.params.venueKey}`).get();
  if (!venue.exists) return;
  await awardReputation({
    userId: event.params.userId, role: 'gourmet', points: 8,
    action: 'gourmet_review', sourceId: `${event.params.venueKey}_${event.params.userId}`,
    label: 'Mekân deneyimini paylaştı', stat: 'gourmetVenueContributions', venueKey: event.params.venueKey,
  });
});

exports.awardUsedCouponReputation = onDocumentUpdated({region: REGION, document: 'users/{userId}/business_coupons/{couponId}'}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (before.status === 'used' || after.status !== 'used') return;
  await awardReputation({
    userId: event.params.userId, role: 'gourmet', points: 5,
    action: 'used_coupon', sourceId: `${event.params.userId}_${event.params.couponId}`,
    label: 'Mekân kuponu kullandı', stat: 'gourmetCoupons', venueKey: after.venueKey,
  });
});

exports.awardCompletedReservationReputation = onDocumentUpdated({region: REGION, document: 'users/{userId}/reservation_history/{reservationId}'}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (before.status === 'prepared' || after.status !== 'prepared') return;
  await awardReputation({
    userId: event.params.userId, role: 'gourmet', points: 5,
    action: 'completed_reservation', sourceId: `${event.params.userId}_${event.params.reservationId}`,
    label: 'Rezervasyonunu tamamladı', stat: 'gourmetReservations', venueKey: after.venueKey,
  });
});

exports.ROLE_DEFINITIONS = ROLE_DEFINITIONS;
exports._normalizeRole = normalizeRole;
exports._evaluateReputation = evaluateReputation;
exports._grantInvitedRole = grantInvitedRole;
exports._awardReputation = awardReputation;
