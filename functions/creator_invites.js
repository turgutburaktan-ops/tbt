const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {randomBytes} = require('node:crypto');
const {isNamedAdmin} = require('./broadcast_policy');

const REGION = 'europe-west1';
const FOUNDING_LIMIT = 100;
const CODE_RE = /^TBT-[A-F0-9]{8}$/;

function normalizeCode(value) {
  return String(value || '').trim().toUpperCase();
}

function requireAdmin(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (!isNamedAdmin(request.auth)) {
    throw new HttpsError('permission-denied', 'Bu işlem yalnız TBT yöneticisine açıktır.');
  }
  return request.auth.uid;
}

function requireUser(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Daveti kullanmak için giriş yap.');
  return request.auth.uid;
}

function inviteState(data) {
  if (!data || data.active !== true) return {valid: false, reason: 'inactive'};
  const expiresAtMs = data.expiresAt?.toMillis?.() || 0;
  if (expiresAtMs && expiresAtMs <= Date.now()) return {valid: false, reason: 'expired'};
  const usesCount = Math.max(0, Number(data.usesCount || 0));
  const maxUses = Math.max(1, Number(data.maxUses || 1));
  if (usesCount >= maxUses) return {valid: false, reason: 'used'};
  return {valid: true, reason: '', usesCount, maxUses, expiresAtMs};
}

async function createUniqueCode(db) {
  for (let i = 0; i < 8; i += 1) {
    const code = `TBT-${randomBytes(4).toString('hex').toUpperCase()}`;
    const ref = db.collection('creator_invites').doc(code);
    if (!(await ref.get()).exists) return {code, ref};
  }
  throw new HttpsError('unavailable', 'Davet kodu üretilemedi. Tekrar dene.');
}

exports.createCreatorInvite = onCall({region: REGION}, async (request) => {
  const adminUid = requireAdmin(request);
  const label = String(request.data?.label || '').trim().slice(0, 80);
  const requestedUses = Number(request.data?.maxUses || 1);
  const requestedDays = Number(request.data?.expiresInDays || 30);
  const maxUses = Number.isInteger(requestedUses) ? Math.min(20, Math.max(1, requestedUses)) : 1;
  const expiresInDays = Number.isInteger(requestedDays) ? Math.min(90, Math.max(1, requestedDays)) : 30;
  const db = getFirestore();
  const {code, ref} = await createUniqueCode(db);
  const expiresAt = Timestamp.fromMillis(Date.now() + expiresInDays * 86400000);
  await ref.create({
    code,
    label,
    active: true,
    maxUses,
    usesCount: 0,
    createdBy: adminUid,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt,
  });
  return {
    ok: true,
    code,
    url: `https://www.trtbt.com/creator/${code}`,
    maxUses,
    expiresAtMs: expiresAt.toMillis(),
  };
});

exports.getCreatorInvitePreview = onCall({region: REGION}, async (request) => {
  const code = normalizeCode(request.data?.code);
  if (!CODE_RE.test(code)) return {valid: false, reason: 'invalid'};
  const db = getFirestore();
  const snap = await db.collection('creator_invites').doc(code).get();
  if (!snap.exists) return {valid: false, reason: 'not-found'};
  const data = snap.data() || {};
  const state = inviteState(data);
  return {
    valid: state.valid,
    reason: state.reason,
    label: state.valid ? String(data.label || '') : '',
    remainingUses: state.valid ? Math.max(0, state.maxUses - state.usesCount) : 0,
    expiresAtMs: state.valid ? state.expiresAtMs : 0,
    program: 'TBT İlk 100 Creator',
  };
});

exports.redeemCreatorInvite = onCall({region: REGION}, async (request) => {
  const uid = requireUser(request);
  const code = normalizeCode(request.data?.code);
  if (!CODE_RE.test(code)) throw new HttpsError('invalid-argument', 'Geçersiz Creator davet kodu.');
  const db = getFirestore();
  const inviteRef = db.collection('creator_invites').doc(code);
  const userRef = db.collection('users').doc(uid);
  const counterRef = db.collection('creator_program').doc('main');
  const redemptionRef = db.collection('creator_invite_redemptions').doc(uid);

  return db.runTransaction(async (tx) => {
    const [inviteSnap, userSnap, counterSnap, redemptionSnap] = await Promise.all([
      tx.get(inviteRef), tx.get(userRef), tx.get(counterRef), tx.get(redemptionRef),
    ]);
    if (!userSnap.exists) throw new HttpsError('failed-precondition', 'Önce TBT profilini oluştur.');
    const user = userSnap.data() || {};
    if (user.accountStatus === 'frozen' || user.disabled === true || user.banned === true) throw new HttpsError('permission-denied', 'Hesap kullanılamıyor.');
    if (user.isCreator === true && redemptionSnap.exists) {
      return {
        ok: true,
        alreadyCreator: true,
        tier: String(user.creatorTier || 'creator'),
        badge: String(user.creatorBadge || 'creator'),
      };
    }
    if (redemptionSnap.exists) {
      throw new HttpsError('already-exists', 'Bu hesap daha önce bir Creator daveti kullandı.');
    }
    if (!inviteSnap.exists) throw new HttpsError('not-found', 'Davet kodu bulunamadı.');
    const invite = inviteSnap.data() || {};
    const state = inviteState(invite);
    if (!state.valid) throw new HttpsError('failed-precondition', 'Bu Creator daveti artık kullanılamıyor.');

    const foundingCount = Math.max(0, Number(counterSnap.data()?.foundingCreatorCount || 0));
    const isFounding = foundingCount < FOUNDING_LIMIT;
    const tier = isFounding ? 'founding' : 'creator';
    const badge = isFounding ? 'founding_creator' : 'creator';
    const currentType = String(user.profileType || 'personal');
    const profileType = currentType === 'personal' || currentType === 'creator'
      ? 'creator'
      : currentType;

    tx.update(inviteRef, {
      usesCount: FieldValue.increment(1),
      lastUsedAt: FieldValue.serverTimestamp(),
    });
    tx.set(userRef, {
      isCreator: true,
      creatorTier: tier,
      creatorBadge: badge,
      creatorInviteCode: code,
      creatorProgramVersion: 1,
      creatorJoinedAt: FieldValue.serverTimestamp(),
      profileType,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.create(redemptionRef, {
      uid,
      code,
      tier,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (isFounding) {
      tx.set(counterRef, {
        foundingCreatorCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return {ok: true, alreadyCreator: false, tier, badge, foundingRemaining: isFounding ? Math.max(0, FOUNDING_LIMIT - foundingCount - 1) : 0};
  });
});
