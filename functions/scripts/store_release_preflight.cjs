'use strict';

// Read-only readiness check. Do not print credentials, create accounts, grant
// claims, send messages, delete venues, or silently deploy production services.
const {isNamedAdmin} = require('../broadcast_policy');
const ADMIN_EMAIL = 'turgutburaktan@gmail.com';

async function checkReadiness({env = process.env, adminSdk, fetcher = fetch, logger = console} = {}) {
  const issues = [];
  const platform = env.RELEASE_PLATFORM || 'all';
  if (!['all', 'android', 'ios'].includes(platform)) {
    throw new Error('Invalid release platform');
  }
  const checkSecrets = names => {
    for (const name of names) {
      if (!env[name]?.trim()) issues.push(`Missing configured secret: ${name}`);
    }
  };
  const checkAds = os => {
    const appKey = `ADMOB_${os}_APP_ID`, unitKey = `ADMOB_NATIVE_${os}`;
    for (const [key, separator] of [[appKey, '~'], [unitKey, '/']]) {
      const value = env[key] || '';
      if (!new RegExp(`^ca-app-pub-[0-9]{16}${separator}[0-9]{10}$`).test(value) ||
          value.startsWith('ca-app-pub-3940256099942544')) {
        issues.push(`Production AdMob configuration required: ${key}`);
      }
    }
  };
  if (platform !== 'ios') {
    checkSecrets(['PLAY_KEYSTORE_BASE64', 'PLAY_KEYSTORE_PASSWORD',
      'PLAY_KEY_ALIAS', 'PLAY_KEY_PASSWORD', 'MAPS_API_KEY']);
    checkAds('ANDROID');
  }
  if (platform !== 'android') {
    checkSecrets(['FIREBASE_IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64',
      'IOS_DISTRIBUTION_P12_BASE64', 'IOS_DISTRIBUTION_P12_PASSWORD',
      'IOS_PROVISIONING_PROFILE_BASE64', 'APP_STORE_CONNECT_API_KEY_ID',
      'APP_STORE_CONNECT_API_ISSUER_ID', 'APP_STORE_CONNECT_API_KEY']);
    checkAds('IOS');
  }
  if (!env.FIREBASE_SERVICE_ACCOUNT) {
    issues.push('Missing configured secret: FIREBASE_SERVICE_ACCOUNT');
  } else {
    let app;
    try {
      const certificate = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
      if (certificate.project_id !== 'en-iyi-cekim-noktasi') {
        throw new Error('Unexpected Firebase project');
      }
      const sdk = adminSdk || require('firebase-admin');
      app = sdk.initializeApp({credential: sdk.credential.cert(certificate)});
      const user = await app.auth().getUserByEmail(ADMIN_EMAIL);
      if (user.disabled || !isNamedAdmin({uid: user.uid, token: {
        ...user.customClaims, email: user.email, email_verified: user.emailVerified,
      }})) issues.push('Owner account does not meet verified-email/admin access policy');
      else logger.log('Owner account satisfies admin access policy');
    } catch (_) {
      // Firebase errors can contain identifiers or request details. Do not dump.
      issues.push('Could not verify owner access using the configured Firebase connection');
    } finally {
      if (app) await app.delete();
    }
  }

  // Empty, unauthenticated requests must be rejected by the callable itself.
  // A 404, HTML gateway response, or unexpected success means not ready.
  for (const [name, expected] of [
    ['signInWithUsername', 'UNAUTHENTICATED'],
    ['sendAdminBroadcast', 'UNAUTHENTICATED'],
    ['adminDeleteVenue', 'UNAUTHENTICATED'],
  ]) {
    try {
      const response = await fetcher(
        `https://europe-west1-en-iyi-cekim-noktasi.cloudfunctions.net/${name}`,
        {method: 'POST', headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({data: {}}), signal: AbortSignal.timeout(15000)},
      );
      const body = await response.json().catch(() => null);
      if (response.ok || body?.error?.status !== expected) {
        issues.push(`Live callable not ready: ${name} (HTTP ${response.status})`);
      } else logger.log(`Live callable rejects unauthenticated input: ${name}`);
    } catch (_) {
      issues.push(`Live callable unreachable: ${name}`);
    }
  }
  return issues;
}

module.exports = {checkReadiness};

if (require.main === module) {
  checkReadiness().then(issues => {
    if (issues.length) {
      issues.forEach(issue => console.error(`::error::${issue}`));
      process.exitCode = 1;
    } else {
      console.log('Basic release prerequisites passed. This is not end-to-end or physical-device QA.');
    }
  }).catch(() => {
    console.error('::error::Release prerequisite check failed; no production data was changed.');
    process.exitCode = 1;
  });
}
