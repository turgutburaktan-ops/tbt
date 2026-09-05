'use strict';

// Exercise the deployed username login with an isolated, temporary account.
// Never impersonate a real user or log passwords/tokens. Remove only records
// created by this invocation; do not create a public profile or send messages.
const admin = require('firebase-admin');
const {randomBytes, createHash} = require('node:crypto');
const API_KEY = 'AIzaSyBDoKy5YMP5-6UJqotfuUA7a74H-x-5miQ';
const BASE = 'https://europe-west1-en-iyi-cekim-noktasi.cloudfunctions.net/';
let stage = 'initialize', app;

async function post(url, body, token) {
  const response = await fetch(url, {method: 'POST',
    headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify(body), signal: AbortSignal.timeout(30000)});
  return {ok: response.ok, status: response.status, body: await response.json().catch(() => null)};
}

async function main() {
  const credential = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  if (credential.project_id !== 'en-iyi-cekim-noktasi') throw new Error();
  app = admin.initializeApp({credential: admin.credential.cert(credential)});
  const auth = app.auth(), db = app.firestore();
  const username = `release_smoke_${randomBytes(6).toString('hex')}`;
  const password = randomBytes(32).toString('base64url');
  const ref = db.collection('usernames').doc(username);
  let createdUser = false, createdReservation = false;
  try {
    stage = 'create isolated test account';
    await auth.createUser({uid: username, email: `${username}@example.invalid`, password,
      displayName: 'TBT Release Smoke Test'});
    createdUser = true;
    await ref.create({uid: username, username, normalized: username,
      releaseSmokeTest: true, createdAt: admin.firestore.FieldValue.serverTimestamp()});
    createdReservation = true;

    stage = 'verify deployed username/password login';
    const login = await post(`${BASE}signInWithUsername`, {data: {username, password}});
    if (!login.ok || typeof login.body?.result?.customToken !== 'string') {
      console.error(`::error::Username login rejected the isolated test (HTTP ${login.status}, ${login.body?.error?.status || 'unexpected response'})`);
      // Classify only existing public messages. Never print response bodies,
      // account data or credentials, and never read private runtime logs.
      const publicFailures = new Map([
        ['Kullanıcı adıyla giriş şu anda kullanılamıyor. E-posta ile giriş yap.', 'custom-token signing'],
        ['Giriş servisine ulaşılamadı. Tekrar dene.', 'password-service timeout'],
      ]);
      console.error(`::error::Public login failure stage: ${publicFailures.get(login.body?.error?.message) || 'unclassified'}`);
      throw new Error();
    }
    if (Object.keys(login.body.result).some(key => key !== 'customToken')) throw new Error();

    console.log('Live username/password verification and custom-token signing passed.');
    stage = 'exchange custom token';
    const exchange = await post(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${API_KEY}`,
      {token: login.body.result.customToken, returnSecureToken: true});
    if (!exchange.ok) {
      const allowedCodes = new Set(['INVALID_CUSTOM_TOKEN', 'CREDENTIAL_MISMATCH',
        'CONFIGURATION_NOT_FOUND', 'OPERATION_NOT_ALLOWED', 'TOO_MANY_ATTEMPTS_TRY_LATER',
        'API_KEY_INVALID', 'USER_DISABLED']);
      const code = String(exchange.body?.error?.message || '').split(' : ')[0];
      console.error(`::error::Custom-token exchange HTTP ${exchange.status}: ${allowedCodes.has(code) ? code : 'unclassified response'}`);
      throw new Error();
    }
    stage = 'validate custom-token exchange response';
    // Unlike signInWithPassword, signInWithCustomToken does not promise localId.
    // Verify identity from the signed ID token below, including revocation.
    // https://firebase.google.com/docs/reference/rest/auth#section-verify-custom-token
    if (typeof exchange.body?.idToken !== 'string' || !exchange.body.idToken) throw new Error();
    stage = 'verify exchanged identity and revocation';
    const decoded = await auth.verifyIdToken(exchange.body.idToken, true);
    if (decoded.uid !== username || decoded.admin === true) throw new Error();

    stage = 'verify admin endpoints deny a normal user';
    for (const name of ['getAdminInsights', 'sendAdminBroadcast', 'adminDeleteVenue']) {
      const check = await post(`${BASE}${name}`, {data: {}}, exchange.body.idToken);
      if (check.ok || check.body?.error?.status !== 'PERMISSION_DENIED') throw new Error();
    }
    console.log('Deployed username login, custom-token exchange and non-admin access restrictions passed.');
  } finally {
    let clean = true;
    if (createdReservation) {
      try {
        await db.runTransaction(async tx => {
          const record = await tx.get(ref);
          if (record.data()?.uid !== username || record.data()?.releaseSmokeTest !== true) throw new Error();
          tx.delete(ref);
        });
        await db.collection('auth_login_limits').doc(createHash('sha256').update(`user:${username}`).digest('hex')).delete();
      } catch (_) { clean = false; }
    }
    if (createdUser) {
      try { await auth.deleteUser(username); } catch (_) { clean = false; }
    }
    if (!clean) {
      console.error(`::error::Cleanup needs attention for isolated test account ${username}`);
      process.exitCode = 1;
    } else console.log('Isolated test account and username reservation removed.');
  }
}

main().catch(() => {
  console.error(`::error::Live authentication check failed at: ${stage}`);
  process.exitCode = 1;
}).finally(async () => { if (app) await app.delete(); });
