const {createHmac, timingSafeEqual} = require('node:crypto');

function escapeHtml(value) {
  return String(value || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function maskEmail(value) {
  const email = String(value || '').trim().toLowerCase();
  const at = email.lastIndexOf('@');
  if (at <= 0) return '***';
  const local = email.slice(0, at);
  const visible = local.length <= 2 ? local.slice(0, 1) : local.slice(0, 2);
  return `${visible}${'*'.repeat(Math.max(3, Math.min(8, local.length - visible.length)))}${email.slice(at)}`;
}

function rateDecision(previous, nowMs, options = {}) {
  const minIntervalMs = Number(options.minIntervalMs || 60 * 1000);
  const hourLimit = Number(options.hourLimit || 5);
  const dayLimit = Number(options.dayLimit || 20);
  const hourMs = 60 * 60 * 1000;
  const dayMs = 24 * hourMs;
  const old = previous || {};
  const lastSentAtMs = Number(old.lastSentAtMs || 0);
  if (lastSentAtMs && nowMs - lastSentAtMs < minIntervalMs) {
    return {
      allowed: false,
      retryAfterSeconds: Math.max(1, Math.ceil((minIntervalMs - (nowMs - lastSentAtMs)) / 1000)),
    };
  }

  const hourStartMs = nowMs - Number(old.hourStartMs || 0) >= hourMs
    ? nowMs : Number(old.hourStartMs || nowMs);
  const dayStartMs = nowMs - Number(old.dayStartMs || 0) >= dayMs
    ? nowMs : Number(old.dayStartMs || nowMs);
  const hourCount = hourStartMs === nowMs ? 0 : Number(old.hourCount || 0);
  const dayCount = dayStartMs === nowMs ? 0 : Number(old.dayCount || 0);
  if (hourCount >= hourLimit || dayCount >= dayLimit) {
    const retryAt = hourCount >= hourLimit ? hourStartMs + hourMs : dayStartMs + dayMs;
    return {
      allowed: false,
      retryAfterSeconds: Math.max(1, Math.ceil((retryAt - nowMs) / 1000)),
    };
  }
  return {
    allowed: true,
    retryAfterSeconds: 60,
    next: {
      hourStartMs,
      hourCount: hourCount + 1,
      dayStartMs,
      dayCount: dayCount + 1,
      lastSentAtMs: nowMs,
    },
  };
}

function webhookStatus(type) {
  return ({
    'email.sent': 'sent',
    'email.delivered': 'delivered',
    'email.delivery_delayed': 'delayed',
    'email.bounced': 'bounced',
    'email.complained': 'complained',
    'email.failed': 'failed',
    'email.suppressed': 'suppressed',
  })[String(type || '')] || '';
}

function verifyWebhookSignature({secret, id, timestamp, signature, payload, nowSeconds = Date.now() / 1000}) {
  if (!secret || !id || !timestamp || !signature || !Buffer.isBuffer(payload)) return false;
  const parsedTimestamp = Number(timestamp);
  if (!Number.isFinite(parsedTimestamp) || Math.abs(nowSeconds - parsedTimestamp) > 5 * 60) return false;
  const encodedSecret = String(secret).replace(/^whsec_/, '');
  let secretBytes;
  try {
    secretBytes = Buffer.from(encodedSecret, 'base64');
  } catch (_) {
    return false;
  }
  if (!secretBytes.length) return false;
  const signed = `${id}.${timestamp}.${payload.toString('utf8')}`;
  const expected = createHmac('sha256', secretBytes).update(signed).digest('base64');
  return String(signature).split(' ').some((candidate) => {
    const value = candidate.startsWith('v1,') ? candidate.slice(3) : '';
    const actual = Buffer.from(value);
    const wanted = Buffer.from(expected);
    return actual.length === wanted.length && timingSafeEqual(actual, wanted);
  });
}

module.exports = {escapeHtml, maskEmail, rateDecision, verifyWebhookSignature, webhookStatus};
