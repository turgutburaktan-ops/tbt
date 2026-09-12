const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
const fs = require('node:fs');
const path = require('node:path');

function loadInvites() {
  const loaded = new Module(__filename);
  loaded.filename = path.join(__dirname, '../role_invites.js');
  const definitions = {
    creator: {label: 'TBT Creator'}, explorer: {label: 'TBT Kâşif'},
    social: {label: 'TBT Sosyal'}, gourmet: {label: 'TBT Gurme'},
  };
  loaded.require = (id) => {
    if (id === 'firebase-functions/v2/https') {
      return {
        onCall: (_, handler) => handler,
        HttpsError: class extends Error {
          constructor(code, message) {
            super(message);
            this.code = code;
          }
        },
      };
    }
    if (id === 'firebase-functions/v2/firestore') {
      return {
        onDocumentCreated: (_, handler) => handler,
        onDocumentUpdated: (_, handler) => handler,
      };
    }
    if (id === 'firebase-admin/firestore') {
      return {getFirestore: () => ({}), FieldValue: {}, Timestamp: {}};
    }
    if (id === './broadcast_policy') return {isNamedAdmin: () => true};
    if (id === './reputation_system') {
      return {
        ROLE_DEFINITIONS: definitions,
        _normalizeRole: (value) => definitions[value] ? value : '',
        _grantInvitedRole: () => ({}),
      };
    }
    return require(id);
  };
  loaded._compile(fs.readFileSync(loaded.filename, 'utf8'), loaded.filename);
  return loaded.exports;
}

const invites = loadInvites();
const now = Date.UTC(2026, 8, 11);

test('private invitation validity enforces active, expiry and usage limits', () => {
  const future = {toMillis: () => now + 86400000};
  assert.equal(invites._inviteState({active: true, expiresAt: future, maxUses: 1, usesCount: 0}, now).valid, true);
  assert.equal(invites._inviteState({active: false, expiresAt: future}, now).reason, 'inactive');
  assert.equal(invites._inviteState({active: true, expiresAt: {toMillis: () => now - 1}}, now).reason, 'expired');
  assert.equal(invites._inviteState({active: true, expiresAt: future, maxUses: 1, usesCount: 1}, now).reason, 'used');
});

test('public preview exposes no recipient email', () => {
  const preview = invites._publicInvite({
    active: true,
    role: 'gourmet',
    label: 'Kişiye özel',
    recipientEmail: 'secret@example.com',
    maxUses: 1,
    usesCount: 0,
    expiresAt: {toMillis: () => now + 86400000},
  }, 'TBT-GRM-12345678');
  assert.equal(preview.valid, true);
  assert.equal(preview.roleLabel, 'TBT Gurme');
  assert.equal('recipientEmail' in preview, false);
});

test('an email-bound invitation cannot be redeemed before email ownership is verified', async () => {
  const records = new Map([
    ['role_invites/TBT-GRM-12345678', {
      active: true,
      role: 'gourmet',
      recipientEmail: 'guest@example.com',
      maxUses: 1,
      usesCount: 0,
      expiresAt: {toMillis: () => Date.now() + 86400000},
    }],
    ['users/user-1', {email: 'guest@example.com'}],
    ['creator_program/main', {}],
  ]);
  const db = {
    doc: (path) => ({path}),
    runTransaction: async (callback) => callback({
      get: async (ref) => ({
        exists: records.has(ref.path),
        data: () => records.get(ref.path),
      }),
    }),
  };
  await assert.rejects(
    invites._redeem(db, {
      uid: 'user-1',
      email: 'guest@example.com',
      emailVerified: false,
      code: 'TBT-GRM-12345678',
    }),
    /e-posta adresini doğrula/,
  );
});
