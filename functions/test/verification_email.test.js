const test = require('node:test');
const assert = require('node:assert/strict');
const {createHmac} = require('node:crypto');
const {
  escapeHtml,
  maskEmail,
  rateDecision,
  verifyWebhookSignature,
  webhookStatus,
} = require('../verification_email_core');

test('email content escapes user-controlled names and masks addresses', () => {
  assert.equal(escapeHtml('<Burak & "TBT">'), '&lt;Burak &amp; &quot;TBT&quot;&gt;');
  assert.equal(maskEmail('turgutburaktan@gmail.com'), 'tu********@gmail.com');
  assert.equal(maskEmail('a@icloud.com'), 'a***@icloud.com');
});

test('rate decision enforces minute, hourly and daily limits', () => {
  const now = 1_800_000_000_000;
  assert.equal(rateDecision({}, now).allowed, true);
  const minute = rateDecision({lastSentAtMs: now - 10_000}, now);
  assert.equal(minute.allowed, false);
  assert.equal(minute.retryAfterSeconds, 50);
  assert.equal(rateDecision({lastSentAtMs: now - 61_000, hourStartMs: now - 100_000, hourCount: 5}, now).allowed, false);
  assert.equal(rateDecision({lastSentAtMs: now - 61_000, hourStartMs: now - 3_700_000,
    hourCount: 5, dayStartMs: now - 100_000, dayCount: 20}, now).allowed, false);
  assert.equal(rateDecision({lastSentAtMs: now - 6000, hourStartMs: now - 100_000,
    hourCount: 19}, now, {minIntervalMs: 5000, hourLimit: 20, dayLimit: 60}).allowed, true);
  assert.equal(rateDecision({lastSentAtMs: now - 6000, hourStartMs: now - 100_000,
    hourCount: 20}, now, {minIntervalMs: 5000, hourLimit: 20, dayLimit: 60}).allowed, false);
});

test('hourly limit stays one hour when the minimum interval is five seconds', () => {
  const now = 1_800_000_000_000;
  const result = rateDecision({
    lastSentAtMs: now - 10_000,
    hourStartMs: now - (30 * 60 * 1000),
    hourCount: 20,
    dayStartMs: now - (2 * 60 * 60 * 1000),
    dayCount: 20,
  }, now, {minIntervalMs: 5000, hourLimit: 20, dayLimit: 60});
  assert.equal(result.allowed, false);
  assert.equal(result.retryAfterSeconds, 30 * 60);
});

test('webhook status accepts only supported delivery events', () => {
  assert.equal(webhookStatus('email.delivered'), 'delivered');
  assert.equal(webhookStatus('email.bounced'), 'bounced');
  assert.equal(webhookStatus('unknown.event'), '');
});

test('webhook signature validates payload and rejects stale or changed input', () => {
  const secretBytes = Buffer.from('test webhook secret');
  const secret = `whsec_${secretBytes.toString('base64')}`;
  const id = 'msg_test';
  const timestamp = '1800000000';
  const payload = Buffer.from('{"type":"email.delivered"}');
  const signature = createHmac('sha256', secretBytes)
    .update(`${id}.${timestamp}.${payload.toString('utf8')}`).digest('base64');
  const input = {secret, id, timestamp, signature: `v1,${signature}`, payload, nowSeconds: 1_800_000_010};
  assert.equal(verifyWebhookSignature(input), true);
  assert.equal(verifyWebhookSignature({...input, payload: Buffer.from('{}')}), false);
  assert.equal(verifyWebhookSignature({...input, nowSeconds: 1_800_000_400}), false);
});
