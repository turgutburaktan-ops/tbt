const {test} = require('node:test');
const assert = require('node:assert/strict');
const {_privatePath, _sealPendingChatMediaHandler: sweep} = require('../chat_media_security');

function harness({failPath, stalePage = false} = {}) {
  const names = [
    'private_chat/thread/alice/message/media.jpg',
    'route_albums/route/alice/media/thumb.jpg',
    'route_chat/route/alice/message/audio.m4a',
    'event_chat/event/alice/message/media.jpg',
    'users/alice/chat/thread/old.jpg',
    'users/alice/chat/thread/old.m4a',
    'users/alice/business_claims/cafe:example/evidence.jpg',
    'users/alice/posts/public.jpg',
    'users/alice/profile/avatar.jpg',
  ];
  const states = new Map(), calls = [], sealed = [];
  const files = names.map(name => {
    let metadata = {metageneration: '1', metadata: {firebaseStorageDownloadTokens: 'synthetic', chatMessageId: 'old'}};
    return {name, get metadata() {return metadata;}, getMetadata: async () => [metadata], setMetadata: async value => {
      if (name === failPath) throw Object.assign(Error('storage unavailable'), {code: 503});
      metadata = {...value, metageneration: '2'};
      sealed.push(name);
    }};
  });
  const db = {doc: path => ({get: async () => ({data: () => ({pageToken: 'prior'})}), set: async value => states.set(path, value)})};
  const bucket = {getFiles: async query => {
    calls.push(query);
    if (stalePage && query.pageToken) throw Object.assign(Error('expired page'), {code: 400});
    return [files.filter(f => f.name.startsWith(query.prefix)), {pageToken: 'next'}];
  }};
  return {db, bucket, states, calls, sealed, files};
}

test('private paths include legacy photo/audio but never public posts or avatars', () => {
  for (const path of ['users/alice/chat/thread/old.jpg', 'users/alice/chat/thread/old.m4a']) assert.equal(_privatePath(path), true);
  for (const path of ['users/alice/posts/p.jpg', 'users/alice/profile/a.jpg', 'users/alice/chat', 'users/alice/chat/thread/nested/file.jpg']) assert.equal(_privatePath(path), false);
});

test('sweep seals every private namespace, preserves legacy message binding and advances each cursor', async () => {
  const h = harness();
  await sweep(h.db, h.bucket);
  assert.equal(h.calls.length, 5);
  assert.equal(h.states.size, 5);
  assert.equal(h.sealed.length, 7);
  for (const state of h.states.values()) assert.equal(state.pageToken, 'next');
  for (const file of h.files) {
    if (!_privatePath(file.name)) {assert.equal(file.metadata.metadata.firebaseStorageDownloadTokens, 'synthetic'); continue;}
    assert.equal(file.metadata.metadata.firebaseStorageDownloadTokens, null);
    assert.equal(file.metadata.metadata.chatSealed, 'true');
    assert.equal(file.metadata.metadata.chatMessageId, 'old');
    assert.equal(file.metadata.cacheControl, 'private, no-store, max-age=0');
  }
});

test('a failed legacy revocation cannot advance the users cursor', async () => {
  const h = harness({failPath: 'users/alice/chat/thread/old.jpg'});
  await assert.rejects(sweep(h.db, h.bucket), /storage unavailable/);
  assert.equal(h.states.has('maintenance_jobs/users_media_seal'), false);
});

test('expired cursors restart a namespace and still seal legacy objects', async () => {
  const h = harness({stalePage: true});
  await sweep(h.db, h.bucket);
  assert.equal(h.calls.length, 10);
  assert(h.sealed.includes('users/alice/chat/thread/old.jpg'));
  assert.equal(h.states.size, 5);
});
