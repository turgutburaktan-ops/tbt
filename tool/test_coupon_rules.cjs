// Run only against the Firestore emulator; never reads production records.
const assert = require('node:assert/strict');
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Local Firestore emulator required');
}
const project = 'demo-tbt';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({iss: `https://securetoken.google.com/${project}`, aud: project, sub: uid, user_id: uid, iat: now, exp: now + 3600, auth_time: now, firebase: {sign_in_provider: 'custom', identities: {}}})}.`;
}
async function request(path, credential, method = 'GET', body) {
  return fetch(`${base}/${path}`, {method, headers: {
    'Content-Type': 'application/json',
    ...(credential ? {Authorization: `Bearer ${credential}`} : {}),
  }, ...(body ? {body: JSON.stringify(body)} : {})});
}
(async () => {
  const published = 'business_venues/dining:test/coupons/offer';
  const wallet = 'users/coupon-owner/business_coupons/offer';
  const claim = 'business_venues/dining:test/coupon_claims/offer_coupon-owner';
  const fields = {fields: {title: {stringValue: 'Test coupon'}}};
  for (const path of [published, wallet, claim]) {
    assert.equal((await request(path, 'owner', 'PATCH', fields)).status, 200);
  }
  assert.equal((await request(published)).status, 200, 'public offer readable');
  assert.equal((await request('business_venues/dining:test/coupons')).status, 200, 'offers list readable');
  assert.equal((await request(wallet, token('coupon-owner'))).status, 200, 'owner wallet readable');
  assert.equal((await request('users/coupon-owner/business_coupons', token('coupon-owner'))).status, 200, 'owner wallet query readable');
  for (const credential of [undefined, token('another-user')]) {
    assert.equal((await request(wallet, credential)).status, 403, 'wallet remains private');
  }
  assert.equal((await request(claim, token('coupon-owner'))).status, 403, 'claims are server-only');
  for (const path of [published, wallet, claim]) {
    assert.equal((await request(path, token('coupon-owner'), 'PATCH', fields)).status, 403, 'client cannot forge coupons');
  }
  console.log('Coupon rules: public offers, private wallet, server-only writes passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
