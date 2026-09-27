const {test} = require('node:test');
const assert = require('node:assert/strict');
const {withAccountLifecycle, LEASE_MS} = require('../account_lifecycle_guard');

function fixture(profile = {accountStatus: 'active'}) {
  const records = new Map(profile ? [['users/u', {...profile}]] : []);
  const ref = path => ({path});
  let queue = Promise.resolve();
  const auth = {disabled: false, async getUser() {return {disabled: this.disabled};}};
  const db = {
    collection: name => ({doc: id => ref(`${name}/${id}`)}),
    runTransaction(work) {
      const result = queue.then(async () => {
        const writes = [];
        const result = await work({
          get: async r => ({exists: records.has(r.path), data: () => records.get(r.path)}),
          set: (r, data, options) => writes.push(() => records.set(r.path, options?.merge ? {...records.get(r.path), ...data} : data)),
          delete: r => writes.push(() => records.delete(r.path)),
        });
        writes.forEach(write => write());
        return result;
      });
      queue = result.catch(() => {});
      return result;
    },
  };
  return {records, auth, run: (operation, work = async () => {}) => withAccountLifecycle({db, auth, uid: 'u', operation}, work)};
}

test('restricted accounts cannot reset their status through freeze or unfreeze', async () => {
  for (const profile of [{accountStatus: 'banned'}, {accountStatus: 'suspended'},
    {accountStatus: 'deleting'}, {accountStatus: 'deleted'}, {accountStatus: 'unexpected'},
    {accountStatus: 'frozen', banned: true}, {accountStatus: 'active', disabled: true}]) {
    for (const operation of ['freeze', 'unfreeze']) {
      const f = fixture(profile);
      await assert.rejects(f.run(operation, () => assert.fail('Must not process content')), {code: 'permission-denied'});
      assert.deepEqual(f.records.get('users/u'), profile);
      assert.equal(f.records.has('account_lifecycle_locks/u'), false);
    }
  }
});

test('disabled Auth accounts are rejected even with an otherwise active profile', async () => {
  const f = fixture(); f.auth.disabled = true;
  await assert.rejects(f.run('freeze'), {code: 'permission-denied'});
  assert.equal(f.records.get('users/u').accountStatus, 'active');
});

test('freeze marks account restricted before content processing; failure stays restricted and retry works', async () => {
  const f = fixture({});
  await assert.rejects(f.run('freeze', async () => {
    assert.equal(f.records.get('users/u').accountStatus, 'frozen');
    throw Error('content unavailable');
  }), /content unavailable/);
  assert.equal(f.records.get('users/u').accountStatus, 'frozen');
  assert.equal(f.records.has('account_lifecycle_locks/u'), false);
  await f.run('freeze');
});

test('unfreeze does not overwrite restrictions applied during content processing', async () => {
  const f = fixture({accountStatus: 'frozen'});
  await assert.rejects(f.run('unfreeze', async () => {
    f.records.set('users/u', {accountStatus: 'suspended'});
  }), {code: 'permission-denied'});
  assert.equal(f.records.get('users/u').accountStatus, 'suspended');
  const g = fixture({accountStatus: 'frozen'});
  await assert.rejects(g.run('unfreeze', async () => {g.auth.disabled = true;}), {code: 'permission-denied'});
  assert.equal(g.records.get('users/u').accountStatus, 'frozen');
});

test('unfreeze activates only after successful processing; missing account is never recreated', async () => {
  const f = fixture({accountStatus: 'frozen'});
  await assert.rejects(f.run('unfreeze', async () => {throw Error('incomplete');}), /incomplete/);
  assert.equal(f.records.get('users/u').accountStatus, 'frozen');
  await f.run('unfreeze', async () => assert.equal(f.records.get('users/u').accountStatus, 'frozen'));
  assert.equal(f.records.get('users/u').accountStatus, 'active');
  const g = fixture({accountStatus: 'frozen'});
  await assert.rejects(g.run('unfreeze', async () => {g.records.delete('users/u');}), {code: 'permission-denied'});
  assert.equal(g.records.has('users/u'), false);
});

test('freeze, unfreeze and delete cannot overlap for one account', async () => {
  const f = fixture();
  let release;
  const paused = new Promise(resolve => {release = resolve;});
  let started;
  const entered = new Promise(resolve => {started = resolve;});
  const running = f.run('freeze', async () => {started(); await paused;});
  await entered;
  try {
    for (const operation of ['freeze', 'unfreeze', 'delete']) await assert.rejects(f.run(operation), {code: 'aborted'});
  } finally {release();}
  await running;
  await f.run('unfreeze');
  assert.equal(f.records.get('users/u').accountStatus, 'active');
});

test('expired lease can be recovered, and cleanup never deletes a newer lease', async () => {
  assert.ok(LEASE_MS > 540000);
  const f = fixture();
  f.records.set('account_lifecycle_locks/u', {token: 'old', expiresAtMs: Date.now() - 1});
  await f.run('freeze', async () => f.records.set('account_lifecycle_locks/u', {token: 'new', expiresAtMs: Date.now() + LEASE_MS}));
  assert.equal(f.records.get('account_lifecycle_locks/u').token, 'new');
});

test('deletion can resume without a profile and never recreates a completed deletion', async () => {
  const f = fixture(null);
  await f.run('delete', async () => {
    assert.equal(f.records.get('users/u').accountStatus, 'deleting');
    f.records.delete('users/u');
  });
  assert.equal(f.records.has('users/u'), false);
  assert.equal(f.records.has('account_lifecycle_locks/u'), false);
});
