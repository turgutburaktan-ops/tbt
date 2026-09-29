const {test} = require('node:test');
const assert = require('node:assert/strict');
const {migrateContactRecord} = require('../../tool/private_contact_migration.cjs');
const deleted = Symbol('deleted');
function fixture(publicData, privateData = {}) {
  const records = new Map([['public', publicData], ['private', privateData]]);
  const db = {async runTransaction(work) {
    const writes = [];
    const result = await work({
      get: async path => ({exists: records.get(path) != null, data: () => records.get(path)}),
      set: (path, data) => writes.push(() => records.set(path, {...records.get(path), ...data})),
      update: (path, data) => writes.push(() => {
        const next = {...records.get(path)};
        for (const [key, value] of Object.entries(data)) value === deleted ? delete next[key] : next[key] = value;
        records.set(path, next);
      }),
    });
    writes.forEach(write => write());
    return result;
  }};
  const run = () => migrateContactRecord({db, publicRef: 'public', privateRef: 'private',
    fieldValue: {delete: () => deleted, serverTimestamp: () => 123}});
  return {records, run};
}
test('migration moves private contacts and preserves the readable social profile', async () => {
  const f = fixture({displayName: 'Synthetic', email: 'old@example.invalid', phoneNumber: '+900000000000'});
  assert.equal(await f.run(), true);
  assert.deepEqual(f.records.get('public'), {displayName: 'Synthetic'});
  assert.equal(f.records.get('private').email, 'old@example.invalid');
  assert.equal(await f.run(), false);
});
test('stale public contacts never overwrite newer or deliberately cleared private values', async () => {
  const f = fixture({email: 'stale@example.invalid', phoneNumber: '+900000000000', verifiedPhoneNumber: '+900000000001'},
    {email: 'current@example.invalid', phoneNumber: null, verifiedPhoneNumber: ''});
  await f.run();
  assert.deepEqual(f.records.get('private'), {email: 'current@example.invalid', phoneNumber: null, verifiedPhoneNumber: '', migratedAt: 123});
  assert.deepEqual(f.records.get('public'), {});
});
test('migration cannot recreate a deleted user and fails without partial writes on read errors', async () => {
  const f = fixture(undefined);
  assert.equal(await f.run(), false);
  let writes = 0;
  await assert.rejects(migrateContactRecord({
    db: {runTransaction: fn => fn({get: async () => {throw Error('read failed');}, set: () => writes++, update: () => writes++})},
    publicRef: 'public', privateRef: 'private', fieldValue: {},
  }), /read failed/);
  assert.equal(writes, 0);
});
