const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {createHash} = require('node:crypto');
const {normalizeUsername, validUsername} = require('./login_policy');

// Public Firebase project identifier, not a service-account credential.
// Never accept a client-supplied endpoint/key when verifying a password.
const WEB_API_KEY = 'AIzaSyBDoKy5YMP5-6UJqotfuUA7a74H-x-5miQ';
const invalidLogin = () => new HttpsError('unauthenticated', 'Kullanıcı adı veya şifre hatalı.');

async function limitAttempts(db, username, ip) {
  const now = Date.now(), windowMs = 15 * 60 * 1000;
  const keys = [[`ip:${ip}`, 60], [`user:${username}`, 20]];
  await db.runTransaction(async tx => {
    const refs = keys.map(([key]) => db.collection('auth_login_limits')
      .doc(createHash('sha256').update(key).digest('hex')));
    const snaps = await Promise.all(refs.map(ref => tx.get(ref)));
    const next = snaps.map(s => {
      const old = s.data() || {};
      return now - Number(old.startedAtMs || 0) >= windowMs
        ? {startedAtMs: now, attempts: 1}
        : {startedAtMs: old.startedAtMs, attempts: Number(old.attempts || 0) + 1};
    });
    if (next.some((value, i) => value.attempts > keys[i][1])) {
      throw new HttpsError('resource-exhausted', 'Çok fazla giriş denemesi. Lütfen 15 dakika sonra tekrar dene.');
    }
    next.forEach((value, i) => tx.set(refs[i], value));
  });
}

exports.signInWithUsername = onCall({region: 'europe-west1', timeoutSeconds: 30}, async request => {
  const username = normalizeUsername(request.data?.username);
  const password = request.data?.password;
  if (!validUsername(username) || typeof password !== 'string' ||
      !password.length || password.length > 4096) throw invalidLogin();
  const db = getFirestore(), adminAuth = getAuth();
  await limitAttempts(db, username, request.rawRequest?.ip || 'unknown');
  try {
    const reservation = await db.collection('usernames').doc(username).get();
    const uid = reservation.data()?.uid;
    if (typeof uid !== 'string' || !uid) throw invalidLogin();
    const account = await adminAuth.getUser(uid);
    if (account.disabled || !account.email) throw invalidLogin();
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
      {method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({email: account.email, password, returnSecureToken: true}),
        signal: AbortSignal.timeout(10000)},
    );
    const result = await response.json();
    if (result.mfaPendingCredential) {
      throw new HttpsError('failed-precondition', 'İki adımlı doğrulama için e-posta ile giriş yap.');
    }
    if (!response.ok || !result.idToken || result.localId !== uid) throw invalidLogin();
    const verified = await adminAuth.verifyIdToken(result.idToken, true);
    if (verified.uid !== uid || account.multiFactor?.enrolledFactors?.length) throw invalidLogin();
    // Never return email, password or upstream token, or log request payloads.
    try {
      return {customToken: await adminAuth.createCustomToken(uid)};
    } catch (_) {
      throw new HttpsError('unavailable', 'Kullanıcı adıyla giriş şu anda kullanılamıyor. E-posta ile giriş yap.');
    }
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (['TimeoutError', 'AbortError'].includes(error?.name)) {
      throw new HttpsError('unavailable', 'Giriş servisine ulaşılamadı. Tekrar dene.');
    }
    throw invalidLogin();
  }
});

// Retire the old resolver without ever disclosing account emails.
exports.resolveUsernameForLogin = onCall({region: 'europe-west1'}, () => {
  throw new HttpsError('failed-precondition', 'Uygulamayı güncelle veya e-posta ile giriş yap.');
});
