const test = require('node:test');
const assert = require('node:assert/strict');
const {checkReadiness} = require('../scripts/store_release_preflight.cjs');

function fixture() {
  const calls = [];
  const user = {uid: 'owner-test-uid', email: 'turgutburaktan@gmail.com',
    emailVerified: true, customClaims: {admin: true}};
  const env = {RELEASE_PLATFORM: 'android',
    FIREBASE_SERVICE_ACCOUNT: JSON.stringify({project_id: 'en-iyi-cekim-noktasi'}),
    ADMOB_ANDROID_APP_ID: 'ca-app-pub-1234567890123456~1234567890',
    ADMOB_NATIVE_ANDROID: 'ca-app-pub-1234567890123456/1234567890'};
  for (const name of ['PLAY_KEYSTORE_BASE64', 'PLAY_KEYSTORE_PASSWORD',
    'PLAY_KEY_ALIAS', 'PLAY_KEY_PASSWORD', 'MAPS_API_KEY']) env[name] = 'test-secret';
  const adminSdk = {credential: {cert: value => value}, initializeApp: () => ({
    auth: () => ({getUserByEmail: async email => {
      assert.equal(email, 'turgutburaktan@gmail.com'); return user;
    }}), delete: async () => {},
  })};
  const fetcher = async (url, options) => {
    calls.push(url);
    assert.equal(options.body, '{"data":{}}');
    assert.equal(options.headers.Authorization, undefined);
    return {status: 401, ok: false, json: async () => ({error: {status: 'UNAUTHENTICATED'}})};
  };
  return {env, adminSdk, fetcher, logger: {log() {}}, user, calls};
}

test('Android preflight accepts configured prerequisites and never needs iOS secrets', async () => {
  const input = fixture();
  assert.deepEqual(await checkReadiness(input), []);
  assert.equal(input.calls.length, 3);
});

test('preflight blocks owner lockout, sample ads, and absent live callables', async () => {
  const input = fixture();
  input.user.emailVerified = false;
  input.env.ADMOB_ANDROID_APP_ID = 'ca-app-pub-3940256099942544~3347511713';
  input.fetcher = async () => ({status: 404, ok: false, json: async () => null});
  const issues = await checkReadiness(input);
  assert.equal(issues.length, 5);
  assert.ok(issues.some(issue => issue.includes('Owner account')));
  assert.ok(issues.some(issue => issue.includes('ADMOB_ANDROID_APP_ID')));
});

test('iOS preflight requires production ad configuration and signing settings', async () => {
  const input = fixture();
  input.env.RELEASE_PLATFORM = 'ios';
  const issues = await checkReadiness(input);
  assert.ok(issues.some(issue => issue.includes('ADMOB_IOS_APP_ID')));
  assert.ok(issues.some(issue => issue.includes('ADMOB_NATIVE_IOS')));
  assert.ok(issues.some(issue => issue.includes('IOS_DISTRIBUTION_P12_BASE64')));
  assert.ok(!issues.some(issue => issue.includes('PLAY_')));
});

test('preflight never emits raw credential or request errors', async () => {
  const input = fixture();
  input.adminSdk.initializeApp = () => {throw new Error('do-not-log-secret');};
  input.fetcher = async () => {throw new Error('do-not-log-secret');};
  const issues = await checkReadiness(input);
  assert.equal(issues.length, 4);
  assert.ok(!JSON.stringify(issues).includes('do-not-log-secret'));
});
