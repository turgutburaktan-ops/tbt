const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness(userCount, interrupt = false) {
  let records = new Map(), commits = 0, interrupted = false;
  const jobPath = 'admin_broadcasts/broadcast_test_0001';
  const ref = path => ({path, id: path.split('/').at(-1), collection: name => ({doc: id => ref(`${path}/${name}/${id}`)})});
  records.set(jobPath, {status: 'queued', title: 'Test title', body: 'Test body', sentBy: 'admin', cursor: null, recipientCount: 0});
  for (let i = 0; i < userCount; i++) records.set(`users/u${String(i).padStart(4, '0')}`, {notificationPreferences: {marketing: i % 2 === 0}});
  const db = {
    collection: () => {
      const q = {query: true, cursor: '', count: 200,
        orderBy: () => q, limit: count => { q.count = count; return q; },
        startAfter: cursor => { q.cursor = cursor; return q; }};
      return q;
    },
    runTransaction: async fn => {
      if (interrupt && commits === 1 && !interrupted) { interrupted = true; throw new Error('temporary interruption'); }
      const staged = new Map(records);
      const result = await fn({
        get: async target => {
          if (!target.query) return {data: () => staged.get(target.path)};
          const users = [...staged].filter(([path]) => /^users\/[^/]+$/.test(path) && path.split('/')[1] > target.cursor)
            .sort(([a], [b]) => a.localeCompare(b)).slice(0, target.count)
            .map(([path, value]) => ({id: path.split('/')[1], ref: ref(path), data: () => value}));
          return {docs: users, size: users.length};
        },
        create: (target, value) => { assert.equal(staged.has(target.path), false, `duplicate ${target.path}`); staged.set(target.path, value); },
        update: (target, value) => staged.set(target.path, {...staged.get(target.path), ...value}),
      });
      records = staged; commits++; return result;
    },
  };
  const ctx = {exports: {}, require: id => {
    if (id === 'firebase-functions/v2/firestore') return {onDocumentCreated: (_, fn) => fn};
    if (id === 'firebase-admin/firestore') return {getFirestore: () => db, FieldPath: {documentId: () => '__name__'}, FieldValue: {serverTimestamp: () => 'server-time'}};
    return require('../broadcast_policy');
  }};
  vm.runInNewContext(fs.readFileSync(require.resolve('../admin_broadcast_worker'), 'utf8'), ctx);
  return {run: () => ctx.exports.deliverAdminBroadcast({data: {ref: ref(jobPath)}}),
    job: () => records.get(jobPath), inbox: () => [...records].filter(([path]) => path.includes('/notifications/'))};
}
test('broadcast delivery paginates and preserves per-user push consent', async () => {
  const h = harness(205); await h.run();
  assert.equal(h.job().status, 'completed');
  assert.equal(h.job().recipientCount, 205);
  assert.equal(h.inbox().length, 205);
  assert.equal(h.inbox().filter(([, n]) => n.pushAllowed).length, 103);
});
test('interrupted delivery resumes without duplicating notifications', async () => {
  const h = harness(205, true);
  await assert.rejects(h.run, /temporary interruption/);
  assert.equal(h.inbox().length, 200);
  await h.run(); await h.run();
  assert.equal(h.inbox().length, 205);
  assert.equal(h.job().recipientCount, 205);
});
test('empty audience completes with an actual count of zero', async () => {
  const h = harness(0); await h.run();
  assert.equal(h.job().status, 'completed');
  assert.equal(h.job().recipientCount, 0);
});
