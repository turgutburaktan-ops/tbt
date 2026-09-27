const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentCreated, onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {randomBytes} = require('node:crypto');
const {isNamedAdmin} = require('./broadcast_policy');
const {ROLE_DEFINITIONS, _normalizeRole, _grantInvitedRole} = require('./reputation_system');

const REGION = 'europe-west1';
const FOUNDING_LIMIT = 100;
const ROLE_CODES = Object.freeze({creator: 'CRT', explorer: 'KSF', social: 'SOS', gourmet: 'GRM'});
const CODE_RE = /^TBT-(CRT|KSF|SOS|GRM)-[A-F0-9]{8}$/;

function clean(value, max = 180) {
  return String(value || '').trim().slice(0, max);
}

function normalizeEmail(value) {
  return clean(value, 240).toLowerCase();
}

function normalizeCode(value) {
  return clean(value, 40).toUpperCase();
}

function requireAdmin(request) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  if (!isNamedAdmin(request.auth)) throw new HttpsError('permission-denied', 'Bu işlem yalnız TBT yöneticisine açıktır.');
  return request.auth.uid;
}

function inviteState(data, nowMs = Date.now()) {
  if (!data || data.active !== true) return {valid: false, reason: 'inactive'};
  const expiresAtMs = data.expiresAt?.toMillis?.() || 0;
  if (expiresAtMs && expiresAtMs <= nowMs) return {valid: false, reason: 'expired'};
  const usesCount = Math.max(0, Number(data.usesCount || 0));
  const maxUses = Math.max(1, Number(data.maxUses || 1));
  if (usesCount >= maxUses) return {valid: false, reason: 'used'};
  return {valid: true, reason: '', usesCount, maxUses, expiresAtMs};
}

async function createUniqueCode(db, role) {
  for (let i = 0; i < 8; i += 1) {
    const code = `TBT-${ROLE_CODES[role]}-${randomBytes(4).toString('hex').toUpperCase()}`;
    const ref = db.doc(`role_invites/${code}`);
    if (!(await ref.get()).exists) return {code, ref};
  }
  throw new HttpsError('unavailable', 'Davet bağlantısı üretilemedi. Tekrar dene.');
}

function publicInvite(data, code) {
  const role = _normalizeRole(data.role);
  const state = inviteState(data);
  return {
    valid: state.valid,
    reason: state.reason,
    role,
    roleLabel: ROLE_DEFINITIONS[role]?.label || '',
    label: state.valid ? clean(data.label, 80) : '',
    remainingUses: state.valid ? Math.max(0, state.maxUses - state.usesCount) : 0,
    expiresAtMs: state.valid ? state.expiresAtMs : 0,
    code,
  };
}

exports.createRoleInvite = onCall({region: REGION}, async (request) => {
  const adminUid = requireAdmin(request);
  const role = _normalizeRole(request.data?.role);
  if (!role) throw new HttpsError('invalid-argument', 'Geçerli bir hesap türü seç.');
  const label = clean(request.data?.label, 80);
  const recipientEmail = normalizeEmail(request.data?.recipientEmail);
  if (recipientEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipientEmail)) {
    throw new HttpsError('invalid-argument', 'Geçerli bir davet e-postası gir.');
  }
  const requestedUses = Number(request.data?.maxUses || 1);
  const requestedDays = Number(request.data?.expiresInDays || 30);
  const maxUses = recipientEmail ? 1 : Number.isInteger(requestedUses) ? Math.min(20, Math.max(1, requestedUses)) : 1;
  const expiresInDays = Number.isInteger(requestedDays) ? Math.min(90, Math.max(1, requestedDays)) : 30;
  const db = getFirestore();
  const {code, ref} = await createUniqueCode(db, role);
  const expiresAt = Timestamp.fromMillis(Date.now() + expiresInDays * 86400000);
  await ref.create({
    code, role, label, recipientEmail, active: true, maxUses, usesCount: 0,
    createdBy: adminUid, createdAt: FieldValue.serverTimestamp(), expiresAt,
  });
  return {
    ok: true, code, role, roleLabel: ROLE_DEFINITIONS[role].label,
    url: `https://www.trtbt.com/davet/${role}/${code}`,
    maxUses, expiresAtMs: expiresAt.toMillis(), recipientBound: Boolean(recipientEmail),
  };
});

exports.getRoleInvitePreview = onCall({region: REGION}, async (request) => {
  const code = normalizeCode(request.data?.code);
  const requestedRole = _normalizeRole(request.data?.role);
  if (!CODE_RE.test(code) || !requestedRole) return {valid: false, reason: 'invalid'};
  const snap = await getFirestore().doc(`role_invites/${code}`).get();
  if (!snap.exists) return {valid: false, reason: 'not-found'};
  const result = publicInvite(snap.data() || {}, code);
  if (result.role !== requestedRole) return {valid: false, reason: 'role-mismatch'};
  return result;
});

async function redeem(db, {uid, email, emailVerified = false, code, expectedRole = '', automatic = false}) {
  const inviteRef = db.doc(`role_invites/${code}`);
  const userRef = db.doc(`users/${uid}`);
  const redemptionRef = db.doc(`role_invite_redemptions/${code}_${uid}`);
  const counterRef = db.doc('creator_program/main');
  return db.runTransaction(async (tx) => {
    const [inviteSnap, userSnap, redemptionSnap, counterSnap] = await Promise.all([
      tx.get(inviteRef), tx.get(userRef), tx.get(redemptionRef), tx.get(counterRef),
    ]);
    if (!inviteSnap.exists) throw new HttpsError('not-found', 'Davet bağlantısı bulunamadı.');
    if (!userSnap.exists) throw new HttpsError('failed-precondition', 'Önce TBT profilini oluştur.');
    const invite = inviteSnap.data() || {};
    const role = _normalizeRole(invite.role);
    if (!role || (expectedRole && role !== expectedRole)) throw new HttpsError('failed-precondition', 'Davet hesap türü eşleşmiyor.');
    const user = userSnap.data() || {};
    if (user.accountStatus === 'frozen' || user.disabled === true || user.banned === true) {
      throw new HttpsError('permission-denied', 'Bu hesap davet kullanamaz.');
    }
    const recipientEmail = normalizeEmail(invite.recipientEmail);
    if (recipientEmail && recipientEmail !== normalizeEmail(email)) {
      throw new HttpsError('permission-denied', 'Bu davet farklı bir e-posta adresine gönderilmiş.');
    }
    if (recipientEmail && emailVerified !== true) {
      throw new HttpsError('failed-precondition', 'Bu daveti almak için e-posta adresini doğrula.');
    }
    if (redemptionSnap.exists) return {ok: true, alreadyActive: true, role, roleLabel: ROLE_DEFINITIONS[role].label};
    const currentRole = user.reputation?.roles?.[role] || user.accountTypes?.[role];
    if (currentRole?.active === true || (role === 'creator' && user.isCreator === true)) {
      return {ok: true, alreadyActive: true, role, roleLabel: ROLE_DEFINITIONS[role].label};
    }
    const state = inviteState(invite);
    if (!state.valid) throw new HttpsError('failed-precondition', 'Bu davet bağlantısı artık kullanılamıyor.');
    const nowMs = Date.now();
    const reputation = _grantInvitedRole(user, role, code, nowMs);
    const now = Timestamp.fromMillis(nowMs);
    const foundingCount = Math.max(0, Number(counterSnap.data()?.foundingCreatorCount || 0));
    const founding = role === 'creator' && foundingCount < FOUNDING_LIMIT;
    const patch = {
      reputation,
      reputationTotal: reputation.total,
      accountTypes: reputation.roles,
      tbtVerified: reputation.verified,
      tbtAmbassador: reputation.ambassador,
      reputationUpdatedAt: now,
      updatedAt: now,
    };
    if (role === 'creator') {
      const currentType = String(user.profileType || 'personal');
      Object.assign(patch, {
        isCreator: true,
        creatorTier: founding ? 'founding' : 'creator',
        creatorBadge: founding ? 'founding_creator' : 'creator',
        creatorProgramVersion: 2,
        creatorJoinedAt: now,
        profileType: currentType === 'personal' || currentType === 'creator' ? 'creator' : currentType,
      });
    }
    tx.update(inviteRef, {usesCount: FieldValue.increment(1), lastUsedAt: now});
    tx.set(userRef, patch, {merge: true});
    tx.create(redemptionRef, {
      uid, code, role, source: automatic ? 'email_auto' : 'link', createdAt: now,
    });
    tx.set(db.doc(`users/${uid}/notifications/role_invite_${role}`), {
      type: 'reputation_role', role,
      title: `${ROLE_DEFINITIONS[role].label} hesabın açıldı`,
      body: 'TBT özel davetin hesabına tanımlandı.', actorId: null, read: false, createdAt: now,
    }, {merge: false});
    if (founding) tx.set(counterRef, {foundingCreatorCount: FieldValue.increment(1), updatedAt: now}, {merge: true});
    return {ok: true, alreadyActive: false, role, roleLabel: ROLE_DEFINITIONS[role].label, founding};
  });
}

exports.redeemRoleInvite = onCall({region: REGION}, async (request) => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Daveti kullanmak için giriş yap.');
  const code = normalizeCode(request.data?.code);
  const role = _normalizeRole(request.data?.role);
  if (!CODE_RE.test(code) || !role) throw new HttpsError('invalid-argument', 'Geçersiz davet bağlantısı.');
  return redeem(getFirestore(), {
    uid: request.auth.uid,
    email: request.auth.token?.email,
    emailVerified: request.auth.token?.email_verified === true,
    code,
    expectedRole: role,
  });
});

async function activateVerifiedInvites(userId) {
  const account = await getAuth().getUser(userId);
  const email = normalizeEmail(account.email);
  if (!account.emailVerified || !email) return;
  const db = getFirestore();
  const matches = await db.collection('role_invites').where('recipientEmail', '==', email).limit(10).get();
  for (const doc of matches.docs) {
    const role = _normalizeRole(doc.data().role);
    if (!role || !inviteState(doc.data()).valid) continue;
    try {
      await redeem(db, {uid: userId, email, emailVerified: true, code: doc.id, expectedRole: role, automatic: true});
    } catch (error) {
      if (!['already-exists', 'failed-precondition', 'permission-denied'].includes(error.code)) throw error;
    }
  }
}

exports.activateEmailRoleInvites = onDocumentCreated({region: REGION, document: 'users/{userId}'}, async (event) => {
  await activateVerifiedInvites(event.params.userId);
});

exports.activateVerifiedEmailRoleInvites = onDocumentUpdated({region: REGION, document: 'users/{userId}'}, async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (before.emailVerified === true || after.emailVerified !== true) return;
  await activateVerifiedInvites(event.params.userId);
});

exports._inviteState = inviteState;
exports._publicInvite = publicInvite;
exports._redeem = redeem;
