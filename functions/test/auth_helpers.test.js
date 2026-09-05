const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {normalizeUsername, validUsername} = require('../login_policy');
const {isNamedAdmin, marketingPushAllowed} = require('../broadcast_policy');

function harness(options = {}) {
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  const records = new Map();
  let fetches = 0, minted = 0;
  const db = {
    collection: name => ({doc: id => ({path: `${name}/${id}`, get: async () => ({
      data: () => name === 'usernames' ? (options.missing ? undefined : {uid: 'user1'}) : records.get(`${name}/${id}`),
    })})}),
    runTransaction: async fn => fn({get: ref => ref.get(), set: (ref, value) => records.set(ref.path, value)}),
  };
  const auth = {
    getUser: async () => ({uid: 'user1', email: 'private@example.com', disabled: options.disabled,
      multiFactor: {enrolledFactors: options.enrolled ? [{}] : []}}),
    verifyIdToken: async (token, checkRevoked) => {
      assert.equal(checkRevoked, true);
      if (options.revoked) throw new Error('revoked');
      return {uid: options.mismatch ? 'wrong' : 'user1'};
    },
    createCustomToken: async uid => { assert.equal(uid, 'user1'); minted++; return 'signed-custom-token'; },
  };
  const ctx = {
    exports: {}, AbortSignal, Date,
    fetch: async (url, init) => {
      fetches++;
      assert.ok(url.startsWith('https://identitytoolkit.googleapis.com/'));
      assert.equal(JSON.parse(init.body).email, 'private@example.com');
      return {ok: !options.badPassword, json: async () => options.mfa ? {mfaPendingCredential: 'pending'} :
        {localId: options.wrongAccount ? 'wrong' : 'user1', idToken: 'server-only-token'}};
    },
    require: id => {
      if (id === 'firebase-functions/v2/https') return {onCall: (_, fn) => fn, HttpsError};
      if (id === 'firebase-admin/firestore') return {getFirestore: () => db};
      if (id === 'firebase-admin/auth') return {getAuth: () => auth};
      return require(id === './login_policy' ? '../login_policy' : id);
    },
  };
  vm.runInNewContext(fs.readFileSync(require.resolve('../auth_helpers'), 'utf8'), ctx);
  return {...ctx.exports, records, counts: () => ({fetches, minted})};
}
const request = {data: {username: '@Test_User', password: 'not-a-real-password'}, rawRequest: {ip: '192.0.2.1'}};

test('username normalization agrees with Turkish username rules', () => {
  assert.equal(normalizeUsername(' @İĞÜŞÖÇ_abc '), 'igusoc_abc');
  assert.equal(validUsername('ab'), false);
  assert.equal(validUsername('abc..def'), false);
  assert.equal(validUsername('test_user'), true);
});
test('successful login exposes only the signed custom token', async () => {
  const h = harness(), result = await h.signInWithUsername(request);
  assert.deepEqual(Object.keys(result), ['customToken']);
  assert.equal(result.customToken, 'signed-custom-token');
  assert.equal(h.counts().minted, 1);
  assert.ok(!JSON.stringify([...h.records]).includes('192.0.2.1'));
});
for (const flag of ['missing', 'disabled', 'badPassword', 'wrongAccount', 'mismatch', 'revoked', 'enrolled']) {
  test(`${flag} rejects without minting a token or disclosing email`, async () => {
    const h = harness({[flag]: true});
    await assert.rejects(() => h.signInWithUsername(request), e => e.code === 'unauthenticated' && !e.message.includes('@'));
    assert.equal(h.counts().minted, 0);
  });
}
test('MFA challenge cannot be bypassed with a custom token', async () => {
  const h = harness({mfa: true});
  await assert.rejects(() => h.signInWithUsername(request), e => e.code === 'failed-precondition');
  assert.equal(h.counts().minted, 0);
});
test('rate limit rejects the twenty-first attempt before password verification', async () => {
  const h = harness();
  for (let i = 0; i < 20; i++) await h.signInWithUsername(request);
  await assert.rejects(() => h.signInWithUsername(request), e => e.code === 'resource-exhausted');
  assert.equal(h.counts().fetches, 20);
});
test('retired resolver never exposes email', () => {
  assert.throws(() => harness().resolveUsernameForLogin(request), e => e.code === 'failed-precondition');
});
test('named admin requires a verified email AND admin claim', () => {
  const token = {email: 'turgutburaktan@gmail.com', admin: true, email_verified: true};
  assert.equal(isNamedAdmin({uid: 'admin', token}), true);
  for (const change of [{admin: false}, {email_verified: false}, {email: 'other@example.com'}]) {
    assert.equal(isNamedAdmin({uid: 'admin', token: {...token, ...change}}), false);
  }
  assert.equal(isNamedAdmin(null), false);
});
test('marketing push defaults off and respects opt-out', () => {
  assert.equal(marketingPushAllowed({}), false);
  assert.equal(marketingPushAllowed({settings: {notifyMarketing: true}}), false);
  assert.equal(marketingPushAllowed({notificationPreferences: {marketing: true}}), true);
  assert.equal(marketingPushAllowed({notificationPreferences: {marketing: true}, settings: {notifyMarketing: false}}), false);
});
