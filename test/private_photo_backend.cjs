const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc} = require('firebase/firestore');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {_privatePhotoHandler: handler} = require('../functions/chat_private_photo');
initializeApp({projectId: 'demo-tbt-access'});
const db = getFirestore();
let env;
const photo = Buffer.from([255,216,255,217]).toString('base64');
const request = (uid, action, extra = {}) => ({auth: {uid}, data: {
  threadId: 'thread', messageId: 'photo1', action, ...extra}});
const call = (uid, action, extra = {}, now) => handler(request(uid, action, extra), db, now);
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-tbt-access',
    firestore: {rules: fs.readFileSync('firestore.rules', 'utf8')}});
});
after(async () => { await env.cleanup(); await db.terminate(); });
beforeEach(async () => {
  await env.clearFirestore();
  await db.doc('chat_threads/thread').set({type: 'direct', requestStatus: 'accepted', memberIds: ['sender','reader']});
  await db.doc('users/sender').set({displayName: 'Sender'});
  await db.doc('users/reader').set({displayName: 'Reader'});
});
const send = (mode = 'once', now) => call('sender', 'send', {mode, bytes: photo}, now);
test('one view consumes bytes atomically; no sender/outsider read and no reset', async () => {
  await send();
  await assert.rejects(call('sender','open'));
  await assert.rejects(call('outsider','open'));
  const result = await call('reader','open');
  assert.equal(result.remaining, 0);
  assert.equal(result.bytes, photo);
  await assert.rejects(call('reader','open'));
  const stored = (await db.doc('chat_private_photos/photo1').get()).data();
  assert.equal(stored.bytes, undefined);
  assert.equal(stored.views.reader, 1);
});
test('replay is one additional view and simultaneous sessions are refused', async () => {
  await send('replay');
  const first = await call('reader','open');
  assert.equal(first.remaining, 1);
  await assert.rejects(call('reader','open'));
  await call('reader','close', {session: 'forged'});
  await assert.rejects(call('reader','open'));
  await call('reader','close', {session: first.session});
  const second = await call('reader','open');
  assert.equal(second.remaining, 0);
  await assert.rejects(call('reader','open'));
});
test('concurrent devices get only one successful open', async () => {
  await send();
  const results = await Promise.allSettled([call('reader','open'), call('reader','open')]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
});
test('private payload is denied even to sender, recipient and admin; message counters immutable', async () => {
  await send();
  for (const uid of ['sender','reader','outsider']) {
    const client = env.authenticatedContext(uid, {admin: true}).firestore();
    await assertFails(getDoc(doc(client, 'chat_private_photos/photo1')));
    await assertFails(setDoc(doc(client, 'chat_private_photos/fake'), {bytes: photo}));
    await assertFails(updateDoc(doc(client, 'chat_threads/thread/messages/photo1'), {photoViews: {}}));
  }
  const client = env.authenticatedContext('sender').firestore();
  await assertFails(setDoc(doc(client,'chat_threads/thread/messages/fake'),
    {type:'private_photo', text:'photo', senderId:'sender', deleted:false}));
});
test('blocks, deletion, removed membership and expiry all revoke access', async () => {
  await send();
  await db.doc('users/reader/blocked/sender').set({});
  await assert.rejects(call('reader','open'));
  await db.doc('users/reader/blocked/sender').delete();
  await db.doc('chat_threads/thread/messages/photo1').update({deleted:true});
  await assert.rejects(call('reader','open'));
  await db.doc('chat_threads/thread/messages/photo1').update({deleted:false});
  await db.doc('chat_threads/thread').update({memberIds:['sender']});
  await assert.rejects(call('reader','open'));
  await db.doc('chat_threads/thread').update({memberIds:['sender','reader']});
  await assert.rejects(call('reader','open',{},Date.now()+8*86400000));
});
test('group quotas are per original recipient, not shared or given to newcomers', async () => {
  await db.doc('chat_threads/thread').update({type:'group',memberIds:['sender','reader','second']});
  await send();
  await call('reader','open');
  assert.equal((await db.doc('chat_private_photos/photo1').get()).data().bytes, photo);
  await db.doc('chat_threads/thread').update({memberIds:['sender','reader','second','new']});
  await assert.rejects(call('new','open'));
  await call('second','open');
  assert.equal((await db.doc('chat_private_photos/photo1').get()).data().bytes, undefined);
});
test('lost close expires without restoring a spent view; retrying send does not reset views', async () => {
  const now = Date.now();
  await send('replay', now);
  await call('reader','open',{},now);
  await send('replay', now);
  const second = await call('reader','open',{},now+120001);
  assert.equal(second.remaining,0);
});
test('anonymous, unsupported modes, invalid ids and oversized content are rejected', async () => {
  await assert.rejects(handler({data:{}},db));
  await assert.rejects(call('sender','send',{mode:'unlimited',bytes:photo}));
  await assert.rejects(call('sender','send',{mode:'once',bytes:'A'.repeat(800000)}));
  await assert.rejects(call('sender','open',{messageId:'../bad'}));
});
