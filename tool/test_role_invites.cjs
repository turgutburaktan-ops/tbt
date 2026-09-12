const assert = require('node:assert/strict');
if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw Error('Local emulator required');
const req = require('node:module').createRequire(require('node:path').resolve(__dirname, '../functions/package.json'));
req('firebase-admin/app').initializeApp({projectId: 'demo-tbt'});
const db = req('firebase-admin/firestore').getFirestore();
const invites = require('../functions/role_invites');
const {_creatorAdmin: admin} = require('../functions/creator_admin');
const named = {uid: 'invite-test-admin', token: {admin: true, email_verified: true, email: 'turgutburaktan@gmail.com'}};
const panel = (action, data = {}, auth = named) => admin({auth, data: {action, ...data}}, db);
const reject = (promise, code) => assert.rejects(promise, e => e.code === code);
(async () => {
  await reject(invites.createRoleInvite.run({data: {role: 'explorer'}}), 'unauthenticated');
  await reject(invites.createRoleInvite.run({auth: {uid: 'invite-guest', token: {}}, data: {role: 'explorer'}}), 'permission-denied');
  await reject(panel('members', {role: 'explorer'}, {uid: 'invite-guest', token: {}}), 'permission-denied');
  for (const role of ['creator', 'explorer', 'social', 'gourmet']) {
    const uid = 'invite-test-' + role;
    await db.doc('users/' + uid).set({displayName: uid, accountStatus: 'active', profileType: 'personal'});
    const created = await invites.createRoleInvite.run({auth: named, data: {role, maxUses: 1}});
    assert.equal(created.role, role);
    assert.ok((await panel('roleInvites', {role})).items.some(i => i.code === created.code));
    const preview = await invites.getRoleInvitePreview.run({data: {role, code: created.code}});
    assert.equal(preview.valid, true);
    assert.equal('recipientEmail' in preview, false);
    const request = {auth: {uid, token: {}}, data: {role, code: created.code}};
    assert.equal((await invites.redeemRoleInvite.run(request)).ok, true);
    assert.equal((await invites.redeemRoleInvite.run(request)).alreadyActive, true);
    assert.equal((await db.doc('role_invites/' + created.code).get()).data().usesCount, 1);
    assert.equal((await db.doc('users/' + uid).get()).data().accountTypes[role].active, true);
    assert.ok((await panel('members', {role})).items.some(i => i.uid === uid));
    await panel('disableRoleInvite', {code: created.code});
    assert.equal((await invites.getRoleInvitePreview.run({data: {role, code: created.code}})).valid, false);
  }
  const created = await invites.createRoleInvite.run({auth: named, data: {role: 'explorer', maxUses: 1}});
  const requests = [];
  for (const uid of ['invite-race-a', 'invite-race-b']) {
    await db.doc('users/' + uid).set({accountStatus: 'active'});
    requests.push({auth: {uid, token: {}}, data: {role: 'explorer', code: created.code}});
  }
  const results = await Promise.allSettled(requests.map(r => invites.redeemRoleInvite.run(r)));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(results.find(r => r.status === 'rejected').reason.code, 'failed-precondition');
  assert.equal((await db.doc('role_invites/' + created.code).get()).data().usesCount, 1);
  console.log('Role invites: admin authorization, four roles, preview, lists, redemption, retry, disable and concurrent usage limits passed');
})().catch(error => {console.error(error); process.exitCode = 1;}).finally(() => db.terminate());
