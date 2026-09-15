const test = require('node:test');
const assert = require('node:assert/strict');
const {_test} = require('../event_reminders');

test('event reminder window covers the one-hour mark across scheduler runs', () => {
  const now = Date.UTC(2026, 8, 10, 9, 0, 0);
  assert.deepEqual(_test.reminderWindow(now), {
    start: now + 50 * 60 * 1000,
    end: now + 70 * 60 * 1000,
  });
});

test('event reminder audience is unique and excludes merely interested users', () => {
  const audience = _test.reminderAudience(
    {hostId: 'host', participantIds: ['host', 'u1', 'u1']},
    [{id: 'u2', status: 'going'}, {id: 'u3', status: 'interested'}],
  );
  assert.deepEqual(audience.sort(), ['host', 'u1', 'u2']);
});

test('event reminder copy includes local time and place', () => {
  const copy = _test.reminderCopy(
    {title: 'Fotoğraf yürüyüşü', locationLabel: 'Harput'},
    Date.UTC(2026, 8, 10, 17, 30, 0),
  );
  assert.equal(copy.title, 'Etkinliğine 1 saat kaldı');
  assert.match(copy.body, /Fotoğraf yürüyüşü/);
  assert.match(copy.body, /20:30/);
  assert.match(copy.body, /Harput/);
});
