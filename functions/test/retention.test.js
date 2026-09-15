const test = require('node:test');
const assert = require('node:assert/strict');
const {_test} = require('../retention');

test('weekly digest describes available content without empty claims', () => {
  assert.match(_test.weeklyDigestCopy(12, 3).body, /12 yeni paylaşım/);
  assert.match(_test.weeklyDigestCopy(5, 0).body, /5 yeni paylaşım/);
  assert.match(_test.weeklyDigestCopy(0, 4).body, /4 etkinlik/);
});
