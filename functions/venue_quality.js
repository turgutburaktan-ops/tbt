const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getFirestore, Timestamp, FieldPath} = require('firebase-admin/firestore');
const {randomBytes, createHash} = require('node:crypto');
const {isNamedAdmin} = require('./broadcast_policy');
const {DAY, LEVELS, ms, validScores, calculate, lifecycle} = require('./venue_quality_policy');
const REGION = 'europe-west1';
const clean = (v, n = 240) => String(v || '').trim().slice(0, n);
function requireAdmin(request) {
  if (!isNamedAdmin(request.auth)) throw new HttpsError('permission-denied', 'Yönetici yetkisi gerekli.');
}
function venueKey(value) {
  const key = clean(value);
  if (!/^(dining|cafe|hotel):[^/\s]{1,210}$/.test(key)) throw new HttpsError('invalid-argument', 'Geçerli bir mekân seç.');
  return key;
}
const hash = value => createHash('sha256').update(value).digest('hex');
async function context(tx, db, key) {
  const base = db.doc(`business_venues/${key}`);
  const [venue, claim, staff] = await Promise.all([
    tx.get(base), tx.get(db.doc(`business_claims/${key}`)), tx.get(base.collection('staff')),
  ]);
  const v = venue.data() || {}, c = claim.data() || {};
  return {base, venue: v, owner: v.verified === true ? v.ownerUid : c.status === 'verified' ? c.applicantUid : '',
    owners: [v.ownerUid, c.applicantUid].filter(Boolean),
    staffEmails: new Set(staff.docs.filter(d => d.data().active !== false).map(d => clean(d.data().email).toLowerCase())),
    staffUids: new Set(staff.docs.filter(d => d.data().active !== false).map(d => d.data().userUid).filter(Boolean))};
}
function affiliated(ctx, uid, email) {
  return ctx.owners.includes(uid) || ctx.staffUids.has(uid) || ctx.staffEmails.has(clean(email).toLowerCase());
}
async function latestProof(tx, db, key, uid, now) {
  const base = db.doc(`business_venues/${key}`);
  const [coupons, reservations, qr] = await Promise.all([
    tx.get(base.collection('coupon_claims').where('userUid', '==', uid)),
    tx.get(base.collection('reservations').where('userUid', '==', uid)),
    tx.get(db.doc(`venue_quality/${key}/visits/${uid}`)),
  ]);
  const proofs = [];
  for (const d of coupons.docs) {
    const r = d.data();
    if (r.status === 'used' && r.validatedBy && r.usedAt) proofs.push({type: 'coupon', at: ms(r.usedAt), path: d.ref.path});
  }
  for (const d of reservations.docs) {
    const r = d.data();
    if (r.status === 'accepted' && r.preparationStatus === 'completed' && r.preparationStartedAt && ms(r.at) <= now && !['reported', 'disputed', 'confirmed_no_show'].includes(r.incidentStatus)) proofs.push({type: 'reservation', at: ms(r.at), path: d.ref.path});
  }
  if (qr.exists && qr.data().at) proofs.push({type: 'qr', at: ms(qr.data().at), path: qr.ref.path});
  return proofs.filter(p => p.at > now - 365 * DAY && p.at <= now).sort((a, b) => b.at - a.at)[0] || null;
}
async function recalculate(db, key, decision) {
  return db.runTransaction(async tx => {
    const ref = db.doc(`venue_quality/${key}`);
    const [snap, rows, ctx] = await Promise.all([tx.get(ref), tx.get(ref.collection('reviews')), context(tx, db, key)]);
    const old = snap.data() || {}, now = Date.now();
    const sourceRefs = rows.docs.map(d => d.data().proof?.path).filter(Boolean);
    const sources = sourceRefs.length ? await tx.getAll(...[...new Set(sourceRefs)].map(path => db.doc(path))) : [];
    const byPath = new Map(sources.map(d => [d.ref.path, d.data()]));
    const metrics = calculate(key.split(':')[0], rows.docs.map(d => {
      const row = d.data(), proof = row.proof, source = byPath.get(proof?.path);
      const validSource = source && (
        (proof.type === 'coupon' && source.userUid === d.id && source.status === 'used' && source.validatedBy && ms(source.usedAt) === proof.at) ||
        (proof.type === 'reservation' && source.userUid === d.id && source.status === 'accepted' && source.preparationStatus === 'completed' && source.preparationStartedAt && ms(source.at) === proof.at && !['reported', 'disputed', 'confirmed_no_show'].includes(source.incidentStatus)) ||
        (proof.type === 'qr' && ms(source.at) >= proof.at)
      );
      return {...row, excluded: !validSource || row.excluded === true || affiliated(ctx, d.id, row.email)};
    }), now);
    const next = {...metrics, ...lifecycle(old, metrics, now), venueKey: key,
      venueName: clean(ctx.venue.venueName || ctx.venue.name || old.venueName || key), category: key.split(':')[0],
      suspended: old.suspended === true, updatedAt: Timestamp.fromMillis(now)};
    const signature = hash(JSON.stringify(metrics));
    next.pending = (metrics.candidate > next.award || next.needsReview) && old.reviewedSignature !== signature && !next.suspended;
    if (decision) {
      if (decision.action === 'approve') {
        if (!metrics.candidate) throw new HttpsError('failed-precondition', 'Mekân henüz ödül koşullarını sağlamıyor.');
        next.award = metrics.candidate;
        next.suspended = false;
        next.belowSinceMs = 0;
        next.needsReview = false;
      } else if (decision.action === 'suspend') {
        next.suspended = true;
      } else if (decision.action === 'remove') {
        next.award = 0;
        next.belowSinceMs = 0;
        next.needsReview = false;
      }
      next.reviewedSignature = signature;
      next.pending = false;
      tx.create(ref.collection('decisions').doc(), {...decision, metrics, previousAward: old.award || 0, award: next.award, at: Timestamp.fromMillis(now)});
    }
    tx.set(ref, next, {merge: true});
    // Only aggregate data is public. Reviewer emails and proof references stay private.
    tx.set(db.doc(`venue_quality_public/${key}`), {
      score: next.score, criteria: next.criteria, count: next.count, recentCount: next.recentCount,
      award: next.suspended ? 0 : next.award, suspended: next.suspended, updatedAt: next.updatedAt,
    });
    return next;
  });
}
exports.venueQuality = onCall({region: REGION}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Giriş yapmalısın.');
  const db = getFirestore(), data = request.data || {}, action = clean(data.action, 30);
  if (action === 'adminList') {
    requireAdmin(request);
    const filter = clean(data.filter, 20);
    let query = db.collection('venue_quality').orderBy(FieldPath.documentId());
    if (filter === 'pending') query = query.where('pending', '==', true);
    if (filter === 'suspended') query = query.where('suspended', '==', true);
    if (data.cursor) query = query.startAfter(venueKey(data.cursor));
    const snap = await query.limit(30).get();
    return {items: snap.docs.map(d => ({id: d.id, ...d.data()})), cursor: snap.size === 30 ? snap.docs.at(-1).id : null};
  }
  const key = venueKey(data.venueKey), ref = db.doc(`venue_quality/${key}`);
  if (action === 'adminReviews') {
    requireAdmin(request);
    let query = ref.collection('reviews').orderBy(FieldPath.documentId());
    if (data.cursor) {
      const cursor = clean(data.cursor, 128);
      if (cursor.includes('/')) throw new HttpsError('invalid-argument', 'Geçersiz sayfa.');
      query = query.startAfter(cursor);
    }
    const rows = await query.limit(50).get();
    return {reviews: rows.docs.map(d => ({id: d.id, scores: d.data().scores, excluded: d.data().excluded === true, proofType: d.data().proof?.type})), cursor: rows.size === 50 ? rows.docs.at(-1).id : null};
  }
  if (action === 'adminDetail') {
    requireAdmin(request);
    await recalculate(db, key);
    const [s, decisions, reviews, reports] = await Promise.all([ref.get(), ref.collection('decisions').orderBy('at', 'desc').limit(30).get(),
      ref.collection('reviews').orderBy(FieldPath.documentId()).limit(50).get(), ref.collection('reports').orderBy('at', 'desc').limit(50).get()]);
    return {item: s.data(), levels: LEVELS, reviewCursor: reviews.size === 50 ? reviews.docs.at(-1).id : null, decisions: decisions.docs.map(d => ({id: d.id, ...d.data(), atMs: ms(d.data().at)})),
      reviews: reviews.docs.map(d => ({id: d.id, scores: d.data().scores, excluded: d.data().excluded === true, proofType: d.data().proof?.type})),
      reports: reports.docs.map(d => ({id: d.id, ...d.data()}))};
  }
  if (action === 'decide') {
    requireAdmin(request);
    const decision = clean(data.decision, 20), reason = clean(data.reason, 700);
    if (!['approve', 'reject', 'suspend', 'remove'].includes(decision) || reason.length < 10) throw new HttpsError('invalid-argument', 'Karar için en az 10 karakter gerekçe yaz.');
    await recalculate(db, key, {action: decision, reason, by: uid});
    return {ok: true};
  }
  if (action === 'resolveReports') {
    requireAdmin(request);
    const reason = clean(data.reason, 700);
    if (reason.length < 10) throw new HttpsError('invalid-argument', 'İnceleme gerekçesi gerekli.');
    const batch = db.batch();
    batch.set(ref, {hasReports: false}, {merge: true});
    batch.create(ref.collection('decisions').doc(), {action: 'resolve_reports', reason, by: uid, at: Timestamp.now()});
    await batch.commit();
    return {ok: true};
  }
  if (action === 'moderate') {
    requireAdmin(request);
    const reviewUid = clean(data.reviewUid, 128), reason = clean(data.reason, 700);
    if (!reviewUid || reviewUid.includes('/') || reason.length < 10 || typeof data.excluded !== 'boolean') throw new HttpsError('invalid-argument', 'Değerlendirme ve gerekçe gerekli.');
    await db.runTransaction(async tx => {
      const reviewRef = ref.collection('reviews').doc(reviewUid), review = await tx.get(reviewRef);
      if (!review.exists) throw new HttpsError('not-found', 'Değerlendirme bulunamadı.');
      tx.update(reviewRef, {excluded: data.excluded});
      tx.set(ref.collection('moderation').doc(reviewUid), {excluded: data.excluded, reason, by: uid});
      tx.create(ref.collection('decisions').doc(), {action: data.excluded ? 'exclude_review' : 'restore_review', reviewUid, reason, by: uid, at: Timestamp.now()});
    });
    await recalculate(db, key);
    return {ok: true};
  }
  if (action === 'report') {
    const reason = clean(data.reason, 700);
    if (reason.length < 10) throw new HttpsError('invalid-argument', 'Sorunu en az 10 karakterle açıkla.');
    await ref.collection('reports').doc(uid).set({reason, userId: uid, at: Timestamp.now()});
    // A report never removes an award automatically.
    await ref.set({hasReports: true}, {merge: true});
    return {ok: true};
  }
  if (action === 'delete') {
    await ref.collection('reviews').doc(uid).delete();
    await recalculate(db, key);
    return {ok: true};
  }
  if (!['status', 'submit', 'createVisit', 'redeemVisit'].includes(action)) throw new HttpsError('invalid-argument', 'Geçersiz işlem.');
  const result = await db.runTransaction(async tx => {
    const now = Date.now(), ctx = await context(tx, db, key);
    const isAffiliated = affiliated(ctx, uid, request.auth.token.email);
    if (action === 'createVisit') {
      if (ctx.owner !== uid) throw new HttpsError('permission-denied', 'Doğrulanmış işletme sahibi gerekli.');
      const token = `TBT-VISIT-${randomBytes(16).toString('hex').toUpperCase()}`;
      // Replacing this document invalidates the preceding unused code.
      tx.set(ref.collection('codes').doc('current'), {tokenHash: hash(token), expiresAt: Timestamp.fromMillis(now + 10 * 60000), used: false, createdBy: uid});
      return {token, expiresAtMs: now + 10 * 60000};
    }
    const [mine, moderation] = await Promise.all([tx.get(ref.collection('reviews').doc(uid)), tx.get(ref.collection('moderation').doc(uid))]);
    if (action === 'redeemVisit') {
      if (isAffiliated) throw new HttpsError('permission-denied', 'Kendi işletmene ziyaret kaydı ekleyemezsin.');
      const code = await tx.get(ref.collection('codes').doc('current'));
      if (!code.exists || code.data().used || ms(code.data().expiresAt) <= now || hash(clean(data.token, 80).toUpperCase()) !== code.data().tokenHash) throw new HttpsError('failed-precondition', 'Ziyaret kodu geçersiz, kullanılmış veya süresi dolmuş.');
      tx.update(code.ref, {used: true, usedBy: uid});
      tx.set(ref.collection('visits').doc(uid), {userId: uid, at: Timestamp.fromMillis(now)});
      return {ok: true};
    }
    const proof = isAffiliated ? null : await latestProof(tx, db, key, uid, now);
    if (action === 'status') return {eligible: Boolean(proof), owner: ctx.owner === uid, affiliated: isAffiliated, mine: mine.data()?.scores || null, excluded: moderation.data()?.excluded === true};
    if (!proof) throw new HttpsError('failed-precondition', 'Değerlendirme için doğrulanmış ziyaret gerekli. İşletme sahibi ve çalışanlar kendi mekânını puanlayamaz.');
    if (!validScores(data.scores)) throw new HttpsError('invalid-argument', 'Beş ölçütün her birine 1–5 arasında puan ver.');
    if (moderation.data()?.excluded) throw new HttpsError('failed-precondition', 'Değerlendirmen incelemede.');
    if (mine.exists && now - ms(mine.data().updatedAt) < 60000) throw new HttpsError('resource-exhausted', 'Yeniden değerlendirmek için bir dakika bekle.');
    tx.set(ref.collection('reviews').doc(uid), {userId: uid, email: clean(request.auth.token.email).toLowerCase(), scores: data.scores, proof, excluded: false, updatedAt: Timestamp.fromMillis(now)});
    tx.set(ref, {venueName: clean(ctx.venue.venueName || ctx.venue.name || data.venueName || key), venueKey: key, category: key.split(':')[0]}, {merge: true});
    return {ok: true};
  });
  if (action === 'submit') await recalculate(db, key);
  return result;
});
exports.refreshVenueQualityReview = onDocumentWritten({region: REGION, document: 'venue_quality/{venueKey}/reviews/{uid}', retry: true}, event => recalculate(getFirestore(), venueKey(event.params.venueKey)));
exports.refreshVenueQualityDaily = onSchedule({region: REGION, schedule: 'every day 03:20', timeZone: 'Europe/Istanbul', timeoutSeconds: 540}, async () => {
  const db = getFirestore();
  let cursor;
  do {
    let query = db.collection('venue_quality').orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) await recalculate(db, doc.id);
    cursor = page.size === 100 ? page.docs.at(-1) : null;
  } while (cursor);
});

// Revoke stale evidence and re-evaluate ownership/staff changes immediately.
for (const [name, document] of [
  ['refreshVenueQualityCoupon', 'business_venues/{venueKey}/coupon_claims/{id}'],
  ['refreshVenueQualityReservation', 'business_venues/{venueKey}/reservations/{id}'],
  ['refreshVenueQualityStaff', 'business_venues/{venueKey}/staff/{id}'],
  ['refreshVenueQualityOwner', 'business_venues/{venueKey}'],
]) {
  exports[name] = onDocumentWritten({region: REGION, document, retry: true}, async event => {
    if (!/^(dining|cafe|hotel):[^/\s]{1,210}$/.test(event.params.venueKey)) return;
    const key = venueKey(event.params.venueKey), db = getFirestore();
    if ((await db.doc(`venue_quality/${key}`).get()).exists) await recalculate(db, key);
  });
}
