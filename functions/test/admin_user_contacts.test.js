const {test} = require('node:test');
const assert = require('node:assert/strict');
const {adminUserEmails} = require('../admin_user_contacts');

test('Admin contacts use current Auth emails, batch within the API limit and deduplicate', async () => {
  const calls = [];
  const auth = {getUsers: async ids => {
    calls.push(ids);
    return {users: ids.filter(({uid}) => uid !== 'deleted').map(({uid}) => ({uid, email: `${uid}@example.invalid`}))};
  }};
  const users = Array.from({length: 150}, (_, i) => `u${i}`);
  const emails = await adminUserEmails([...users, 'u1', 'deleted'], auth);
  assert.deepEqual(calls.map(c => c.length), [100, 51]);
  assert.equal(emails.size, 150);
  assert.equal(emails.get('u1'), 'u1@example.invalid');
  assert.equal(emails.has('deleted'), false);
});

test('Auth errors propagate instead of falling back to public profile contacts', async () => {
  await assert.rejects(adminUserEmails(['u1'], {getUsers: async () => {throw Error('auth unavailable');}}), /auth unavailable/);
});
