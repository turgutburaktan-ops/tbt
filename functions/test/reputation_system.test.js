const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const fs = require('node:fs');
const path = require('node:path');

function loadSystem() {
  const loaded = new Module(__filename);
  loaded.filename = path.join(__dirname, '../reputation_system.js');
  const Timestamp = {
    fromMillis: (value) => ({toMillis: () => value}),
    now: () => ({toMillis: () => Date.now()}),
  };
  loaded.require = (id) => {
    if (id === 'firebase-functions/v2/https') {
      return {
        onCall: (_, handler) => handler,
        HttpsError: class extends Error {},
      };
    }
    if (id === 'firebase-functions/v2/firestore') {
      return {
        onDocumentCreated: (_, handler) => handler,
        onDocumentUpdated: (_, handler) => handler,
      };
    }
    if (id === 'firebase-admin/firestore') {
      return {getFirestore: () => ({}), Timestamp};
    }
    return require(id);
  };
  loaded._compile(fs.readFileSync(loaded.filename, 'utf8'), loaded.filename);
  return loaded.exports;
}

const system = loadSystem();
const DAY = 86400000;
const now = Date.UTC(2026, 8, 11);

test('each role requires its own score and concrete contribution conditions', () => {
  const user = {
    createdAt: {toMillis: () => now - 120 * DAY},
    phoneVerified: true,
    reputationEmailVerified: true,
  };
  const result = system._evaluateReputation(user, {
    scores: {creator: 500, explorer: 400, social: 350, gourmet: 400},
    stats: {
      creatorContent: 25,
      explorerApprovedSpots: 10,
      explorerLocatedPosts: 20,
      explorerCities: ['elazig', 'ankara', 'izmir'],
      socialHostedCompleted: 5,
      socialAttendance: 10,
      gourmetVenues: Array.from({length: 15}, (_, i) => `venue-${i}`),
      gourmetPhotoReviews: 10,
    },
  }, now);
  assert.equal(result.roles.creator.active, true);
  assert.equal(result.roles.explorer.active, true);
  assert.equal(result.roles.social.active, true);
  assert.equal(result.roles.gourmet.active, true);
  assert.equal(result.total, 1650);
  assert.equal(result.verified, true);
  assert.equal(result.ambassador, true);
});

test('an invite activates only its selected role and never adds points', () => {
  const user = {createdAt: {toMillis: () => now - 10 * DAY}};
  const result = system._grantInvitedRole(user, 'gourmet', 'TBT-GRM-12345678', now);
  assert.equal(result.roles.gourmet.active, true);
  assert.equal(result.roles.gourmet.source, 'invite');
  assert.equal(result.roles.creator.active, false);
  assert.equal(result.roles.explorer.active, false);
  assert.equal(result.roles.social.active, false);
  assert.deepEqual(result.scores, {creator: 0, explorer: 0, social: 0, gourmet: 0});
  assert.equal(result.total, 0);
  assert.equal(result.verified, false);
});

test('verification needs real points in at least two areas and a clean mature account', () => {
  const base = {
    createdAt: {toMillis: () => now - 120 * DAY},
    phoneVerified: true,
    reputationEmailVerified: true,
  };
  assert.equal(system._evaluateReputation(base, {
    scores: {creator: 1000},
  }, now).verified, false);
  assert.equal(system._evaluateReputation({...base, banned: true}, {
    scores: {creator: 500, explorer: 500},
  }, now).verified, false);
  assert.equal(system._evaluateReputation(base, {
    scores: {creator: 500, explorer: 500},
  }, now).verified, true);
});

test('legacy Creator remains active while the other role tracks remain independent', () => {
  const result = system._evaluateReputation({isCreator: true}, {} , now);
  assert.equal(result.roles.creator.active, true);
  assert.equal(result.roles.creator.source, 'legacy_creator');
  assert.equal(result.roles.explorer.active, false);
});

test('a new invitation preserves other previously invited account types', () => {
  const user = {
    accountTypes: {
      social: {active: true, source: 'invite', inviteCode: 'TBT-SOS-OLD'},
    },
  };
  const result = system._grantInvitedRole(
    user,
    'gourmet',
    'TBT-GRM-NEW',
    now,
  );
  assert.equal(result.roles.social.active, true);
  assert.equal(result.roles.social.source, 'invite');
  assert.equal(result.roles.gourmet.active, true);
  assert.equal(result.total, 0);
});
