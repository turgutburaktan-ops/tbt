const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const crypto = require('crypto');

function clean(value, max = 300) { return String(value || '').trim().slice(0, max); }
function auth(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  return request.auth.uid;
}
function namedAdmin(request) {
  return request.auth?.token?.admin === true &&
    String(request.auth?.token?.email || '').toLowerCase() === 'turgutburaktan@gmail.com';
}
async function businessOwner(request, venueKey, {adminRead = false} = {}) {
  const uid = auth(request);
  const db = getFirestore();
  const [venue, claim] = await Promise.all([
    db.collection('business_venues').doc(venueKey).get(),
    db.collection('business_claims').doc(venueKey).get(),
  ]);
  const v = venue.data() || {}, c = claim.data() || {};
  const owns = (v.verified === true && v.ownerUid === uid) ||
    (c.status === 'verified' && c.applicantUid === uid);
  if (!owns && !(adminRead && namedAdmin(request))) {
    throw new HttpsError('permission-denied', 'Doğrulanmış işletme sahibi gerekli.');
  }
  return {uid, db, venueRef: db.collection('business_venues').doc(venueKey), venue: v};
}

exports.getBusinessWebTools = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240);
  const {venueRef, venue} = await businessOwner(request, venueKey, {adminRead: true});
  const [coupons, staff, collaborations, badges] = await Promise.all([
    venueRef.collection('coupons').orderBy('createdAt', 'desc').limit(100).get().catch(() => ({docs: []})),
    venueRef.collection('staff').orderBy('createdAt', 'desc').limit(50).get().catch(() => ({docs: []})),
    venueRef.collection('collaborations').orderBy('createdAt', 'desc').limit(50).get().catch(() => ({docs: []})),
    venueRef.collection('badge_applications').orderBy('createdAt', 'desc').limit(50).get().catch(() => ({docs: []})),
  ]);
  const mapDoc = doc => {
    const d = doc.data() || {};
    return {id: doc.id, ...d, createdAtMs: d.createdAt?.toMillis?.() || 0, validUntilMs: d.validUntil?.toMillis?.() || 0};
  };
  return {
    routeSettings: venue.routeSettings || {},
    coupons: coupons.docs.map(mapDoc),
    staff: staff.docs.map(mapDoc),
    collaborations: collaborations.docs.map(mapDoc),
    badges: badges.docs.map(mapDoc),
  };
});

exports.saveBusinessRouteSettings = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240);
  const {venueRef} = await businessOwner(request, venueKey);
  const settings = {
    enabled: request.data?.enabled !== false,
    suggestedStopMinutes: Math.min(240, Math.max(10, Number(request.data?.suggestedStopMinutes || 45))),
    recommendationText: clean(request.data?.recommendationText, 500),
    bestVisitTime: clean(request.data?.bestVisitTime, 120),
  };
  await venueRef.set({routeSettings: settings, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {ok: true, routeSettings: settings};
});

exports.createBusinessCoupon = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240);
  const {venueRef, uid} = await businessOwner(request, venueKey);
  const title = clean(request.data?.title, 160), description = clean(request.data?.description, 700);
  const validUntilMs = Number(request.data?.validUntilMs || 0);
  const maxClaims = Math.min(100000, Math.max(1, Number(request.data?.maxClaims || 100)));
  if (title.length < 3 || validUntilMs <= Date.now()) throw new HttpsError('invalid-argument', 'Kupon başlığı ve geçerlilik tarihi gerekli.');
  const ref = venueRef.collection('coupons').doc();
  await ref.set({title, description, validUntil: Timestamp.fromMillis(validUntilMs), maxClaims, claimCount: 0, useCount: 0, active: true, createdBy: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
  return {id: ref.id};
});

exports.claimBusinessCoupon = onCall({region: 'europe-west1'}, async request => {
  const uid = auth(request), venueKey = clean(request.data?.venueKey, 240), couponId = clean(request.data?.couponId, 180);
  const db = getFirestore(), venueRef = db.collection('business_venues').doc(venueKey), couponRef = venueRef.collection('coupons').doc(couponId), claimRef = venueRef.collection('coupon_claims').doc(`${couponId}_${uid}`);
  const result = await db.runTransaction(async transaction => {
    const [couponSnap, existing] = await Promise.all([transaction.get(couponRef), transaction.get(claimRef)]);
    const coupon = couponSnap.data() || {};
    if (existing.exists) return existing.data();
    if (!couponSnap.exists || coupon.active === false || coupon.validUntil?.toMillis?.() <= Date.now()) throw new HttpsError('failed-precondition', 'Bu kupon artık kullanılamıyor.');
    if (Number(coupon.claimCount || 0) >= Number(coupon.maxClaims || 0)) throw new HttpsError('resource-exhausted', 'Kupon kontenjanı doldu.');
    const token = `TBT-${crypto.randomBytes(12).toString('hex').toUpperCase()}`;
    const data = {token, couponId, venueKey, userUid: uid, status: 'ready', title: clean(coupon.title, 160), validUntil: coupon.validUntil, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()};
    transaction.set(claimRef, data);
    transaction.set(db.collection('users').doc(uid).collection('business_coupons').doc(`${venueKey}_${couponId}`.replace(/\//g, '_')), data);
    transaction.update(couponRef, {claimCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()});
    return data;
  });
  return {...result, validUntilMs: result.validUntil?.toMillis?.() || 0};
});

exports.validateBusinessCoupon = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), token = clean(request.data?.token, 120).toUpperCase();
  const {venueRef, db, uid} = await businessOwner(request, venueKey);
  const query = await venueRef.collection('coupon_claims').where('token', '==', token).limit(1).get();
  if (query.empty) throw new HttpsError('not-found', 'Kupon bulunamadı.');
  const claim = query.docs[0], data = claim.data() || {};
  if (data.status !== 'ready') throw new HttpsError('failed-precondition', 'Kupon daha önce kullanılmış veya geçersiz.');
  if (data.validUntil?.toMillis?.() <= Date.now()) throw new HttpsError('failed-precondition', 'Kuponun süresi dolmuş.');
  const batch = db.batch();
  batch.update(claim.ref, {status: 'used', usedAt: FieldValue.serverTimestamp(), validatedBy: uid, updatedAt: FieldValue.serverTimestamp()});
  batch.set(venueRef.collection('coupons').doc(data.couponId), {useCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  batch.set(db.collection('users').doc(data.userUid).collection('business_coupons').doc(`${venueKey}_${data.couponId}`.replace(/\//g, '_')), {status: 'used', usedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  await batch.commit();
  return {ok: true, title: clean(data.title, 160)};
});

exports.addBusinessStaff = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), email = clean(request.data?.email, 240).toLowerCase(), role = clean(request.data?.role, 60) || 'staff';
  const {venueRef, uid} = await businessOwner(request, venueKey);
  if (!email.includes('@')) throw new HttpsError('invalid-argument', 'Geçerli bir e-posta gir.');
  const id = Buffer.from(email).toString('base64url');
  await venueRef.collection('staff').doc(id).set({email, role, active: true, addedBy: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {id};
});

exports.removeBusinessStaff = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), staffId = clean(request.data?.staffId, 240);
  const {venueRef} = await businessOwner(request, venueKey);
  if (!staffId) throw new HttpsError('invalid-argument', 'Yetkili kaydı gerekli.');
  await venueRef.collection('staff').doc(staffId).delete();
  return {ok: true};
});

exports.createBusinessCollaboration = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), partnerName = clean(request.data?.partnerName, 160), title = clean(request.data?.title, 160), description = clean(request.data?.description, 700);
  const {venueRef, uid} = await businessOwner(request, venueKey);
  if (!partnerName || !title) throw new HttpsError('invalid-argument', 'Ortak ve kampanya adı gerekli.');
  const ref = venueRef.collection('collaborations').doc();
  await ref.set({partnerName, title, description, status: 'draft', createdBy: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
  return {id: ref.id};
});

exports.submitBusinessBadgeApplication = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), badgeType = clean(request.data?.badgeType, 80), note = clean(request.data?.note, 700);
  const {venueRef, uid} = await businessOwner(request, venueKey);
  if (!badgeType) throw new HttpsError('invalid-argument', 'Rozet türü gerekli.');
  const ref = venueRef.collection('badge_applications').doc();
  await ref.set({badgeType, note, status: 'pending_review', applicantUid: uid, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
  return {id: ref.id};
});

exports.getBusinessReviews = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240);
  const {db} = await businessOwner(request, venueKey, {adminRead: true});
  const snapshot = await db.collection('venue_ratings').doc(venueKey)
    .collection('ratings').orderBy('updatedAt', 'desc').limit(100).get();
  return {reviews: snapshot.docs.map(doc => {
    const d = doc.data() || {};
    return {id: doc.id, userName: clean(d.userName, 160), rating: Number(d.rating || 0), comment: clean(d.comment, 700), businessReply: clean(d.businessReply, 700), reportedByBusiness: d.reportedByBusiness === true, updatedAtMs: d.updatedAt?.toMillis?.() || 0};
  })};
});

exports.respondBusinessReview = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), reviewId = clean(request.data?.reviewId, 180), reply = clean(request.data?.reply, 700);
  const {db, uid} = await businessOwner(request, venueKey);
  if (!reviewId || !reply) throw new HttpsError('invalid-argument', 'Yorum ve işletme yanıtı gerekli.');
  const ref = db.collection('venue_ratings').doc(venueKey).collection('ratings').doc(reviewId);
  if (!(await ref.get()).exists) throw new HttpsError('not-found', 'Yorum bulunamadı.');
  await ref.set({businessReply: reply, businessReplyBy: uid, businessReplyAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {ok: true};
});

exports.reportBusinessReview = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), reviewId = clean(request.data?.reviewId, 180), reason = clean(request.data?.reason, 500);
  const {db, uid} = await businessOwner(request, venueKey);
  if (!reviewId || !reason) throw new HttpsError('invalid-argument', 'Rapor nedeni gerekli.');
  const reviewRef = db.collection('venue_ratings').doc(venueKey).collection('ratings').doc(reviewId);
  const reportRef = db.collection('moderation_reports').doc();
  const batch = db.batch();
  batch.set(reportRef, {type: 'business_review', venueKey, reviewId, reason, reportedBy: uid, status: 'pending', createdAt: FieldValue.serverTimestamp()});
  batch.set(reviewRef, {reportedByBusiness: true, businessReportId: reportRef.id, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  await batch.commit();
  return {ok: true};
});

exports.sendBusinessFollowerNotification = onCall({region: 'europe-west1'}, async request => {
  const venueKey = clean(request.data?.venueKey, 240), title = clean(request.data?.title, 120), message = clean(request.data?.message, 400);
  const {venueRef, db, uid, venue} = await businessOwner(request, venueKey);
  if (!title || !message) throw new HttpsError('invalid-argument', 'Bildirim başlığı ve mesajı gerekli.');
  const followers = await venueRef.collection('followers').limit(500).get();
  const batch = db.batch();
  followers.docs.forEach(doc => batch.set(db.collection('users').doc(doc.id).collection('notifications').doc(), {type: 'business_announcement', venueKey, venueName: clean(venue.venueName, 160), title, message, fromBusinessUid: uid, read: false, createdAt: FieldValue.serverTimestamp()}));
  await batch.commit();
  return {sent: followers.size};
});
