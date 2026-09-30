const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const fs = require('node:fs');
const path = require('node:path');

function fixture(storageFails=false) {
  const records = new Map([
    ['users/customer', {username: 'customer'}],
    ['users/other', {username: 'other'}],
    ['business_venues/venue/reservations/own', {userUid: 'customer', contactPhone: 'private', orderItems: [{name: 'Meal'}]}],
    ['business_venues/venue/reservations/other', {userUid: 'other', contactPhone: 'other-private'}],
    ['reservation_disputes/own', {userUid: 'customer', customerName: 'Customer'}],
    ['reservation_disputes/other', {userUid: 'other'}],
  ]);
  const deletedAuth = [];
  const deletedFiles=[];
  const ref = key => ({path: key, get: async () => ({exists: records.has(key), data: () => records.get(key)}),
    set: async data => records.set(key, {...records.get(key), ...data}), delete: async () => records.delete(key)});
  function query(name, group = false, filters = [], limit = Infinity) {
    return {
      doc: id => ref(`${name}/${id}`),
      where: (field, operator, value) => {
        assert.equal(operator, '==');
        return query(name, group, [...filters, [field, value]], limit);
      },
      limit: count => query(name, group, filters, count),
      get: async () => {
        const docs = [...records].filter(([key, value]) => {
          const parts = key.split('/');
          return (group ? parts.at(-2) === name : parts.slice(0, -1).join('/') === name) &&
            filters.every(([field, expected]) => value[field] === expected);
        }).slice(0, limit).map(([key, value]) => ({ref: ref(key), data: () => value}));
        return {empty: docs.length === 0, size: docs.length, docs};
      },
    };
  }
  const db = {collection: name => query(name), collectionGroup: name => query(name, true),
    runTransaction: async work => work({get: r => r.get(), set: (r, data) => r.set(data), delete: r => r.delete()}),
    recursiveDelete: async item => {
      for (const key of records.keys()) if (key === item.path || key.startsWith(`${item.path}/`)) records.delete(key);
    }};
  class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
  const loaded = new Module(__filename);
  loaded.require = id => {
    if (id === 'firebase-functions/v2/https') return {onCall: (_, handler) => handler, HttpsError};
    if (id === 'firebase-admin/firestore') return {getFirestore: () => db, FieldValue: {serverTimestamp: () => 1}};
    if (id === 'firebase-admin/auth') return {getAuth: () => ({deleteUser: async uid => deletedAuth.push(uid)})};
    if (id === 'firebase-admin/storage') return {getStorage: () => ({bucket: () => ({deleteFiles: async () => {if(storageFails)throw Error('Storage unavailable');}, getFiles: async()=>[[...['private_chat/t/customer/m/media.jpg','private_chat/t/other/m/media.jpg'].map(name=>({name,delete:async()=>deletedFiles.push(name)}))],null]})})};
    if (id === './account_lifecycle_guard') return require('../account_lifecycle_guard');
    return Module.createRequire(path.join(__dirname, '../account_lifecycle.js'))(id);
  };
  const source = path.join(__dirname, '../account_lifecycle.js');
  loaded._compile(fs.readFileSync(source, 'utf8'), source);
  return {remove: loaded.exports.deleteAccountNow, records, deletedAuth, deletedFiles};
}

test('account deletion removes own reservation and dispute data while preserving other customers', async () => {
  const f = fixture();
  for (const [path, data] of [
    ['post_reposts/own', {userId:'customer',postId:'original'}],
    ['post_bookmarks/own', {userId:'customer',postId:'original'}],
    ['creator_profiles/customer', {pinnedPostIds:['original']}],
    ['creator_stats/customer/content/original', {views:3}],
    ['creator_referrals/reader', {userId:'reader',creatorId:'customer'}],
    ['post_reposts/other', {userId:'other',postId:'original'}],
  ]) f.records.set(path,data);
  const result = await f.remove({auth: {uid: 'customer', token:{auth_time:Math.floor(Date.now()/1000)}}, data: {uid: 'other'}});
  for (const path of ['post_reposts/own','post_bookmarks/own','creator_profiles/customer','creator_stats/customer/content/original','creator_referrals/reader']) assert.equal(f.records.has(path),false);
  assert.equal(f.records.has('post_reposts/other'),true);

  assert.equal(result.status, 'deleted');
  assert.equal(f.records.has('business_venues/venue/reservations/own'), false);
  assert.equal(f.records.has('reservation_disputes/own'), false);
  assert.equal(f.records.has('users/customer'), false);
  assert.equal(f.records.has('business_venues/venue/reservations/other'), true);
  assert.equal(f.records.has('reservation_disputes/other'), true);
  assert.equal(f.records.has('users/other'), true);
  assert.deepEqual(f.deletedAuth, ['customer']);
  assert.ok(f.deletedFiles.length>0);
  assert.ok(f.deletedFiles.every(name=>name.split('/')[2]==='customer'));
});

test('account deletion requires an authenticated session', async () => {
  const f = fixture();
  await assert.rejects(f.remove({data: {uid: 'customer'}}), {code: 'unauthenticated'});
  assert.equal(f.records.size, 6);
  assert.deepEqual(f.deletedAuth, []);
});


test('deletion rejects stale authentication before any data mutation',async()=>{
 const f=fixture();await assert.rejects(f.remove({auth:{uid:'customer',token:{auth_time:1}}}),{code:'failed-precondition'});
 assert.equal(f.records.size,6);assert.deepEqual(f.deletedAuth,[]);
});
test('missing public profile does not skip private data cleanup',async()=>{
 const f=fixture();f.records.delete('users/customer');
 await f.remove({auth:{uid:'customer',token:{auth_time:Math.floor(Date.now()/1000)}}});
 assert.equal(f.records.has('reservation_disputes/own'),false);assert.deepEqual(f.deletedAuth,['customer']);
});
test('storage cleanup failure preserves auth for retry',async()=>{
 const f=fixture(true);await assert.rejects(f.remove({auth:{uid:'customer',token:{auth_time:Math.floor(Date.now()/1000)}}}),/Storage unavailable/);
 assert.deepEqual(f.deletedAuth,[]);assert.equal(f.records.has('users/customer'),true);
});
