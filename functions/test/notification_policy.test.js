const test = require('node:test');
const assert = require('node:assert/strict');
const {preferenceKeyForType, pushPreferenceAllowed} = require('../notification_policy');

test('notification types map to user-facing preference groups', () => {
  assert.equal(preferenceKeyForType('message'), 'messages');
  assert.equal(preferenceKeyForType('post_like'), 'likes');
  assert.equal(preferenceKeyForType('post_comment'), 'comments');
  assert.equal(preferenceKeyForType('event_reminder'), 'events');
  assert.equal(preferenceKeyForType('business_preparation_reminder'), 'reservations');
  assert.equal(preferenceKeyForType('story_mention'), 'social');
  assert.equal(preferenceKeyForType('reengagement'), 'recommendations');
  assert.equal(preferenceKeyForType('tbt_broadcast'), 'marketing');
});

test('transactional notifications default on and respect explicit opt-out', () => {
  assert.equal(pushPreferenceAllowed({}, 'message'), true);
  assert.equal(pushPreferenceAllowed({notificationPreferences: {messages: false}}, 'message'), false);
  assert.equal(pushPreferenceAllowed({notificationPreferences: {events: false}}, 'event_reminder'), false);
  assert.equal(pushPreferenceAllowed({notificationPreferences: {reservations: false}}, 'business_reservation'), false);
  assert.equal(pushPreferenceAllowed({settings: {notifyPush: false}}, 'follow'), false);
});

test('marketing is opt-in while recommendations retain backwards compatibility', () => {
  assert.equal(pushPreferenceAllowed({}, 'tbt_broadcast'), false);
  assert.equal(pushPreferenceAllowed({notificationPreferences: {marketing: true}}, 'tbt_broadcast'), true);
  assert.equal(pushPreferenceAllowed({}, 'reengagement'), true);
  assert.equal(pushPreferenceAllowed({notificationPreferences: {recommendations: false}}, 'reengagement'), false);
  assert.equal(pushPreferenceAllowed({pushReengagementEnabled: false}, 'reengagement'), false);
});
