const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {createHash} = require('node:crypto');
const {
  escapeHtml,
  maskEmail,
  rateDecision,
  verifyWebhookSignature,
  webhookStatus,
} = require('./verification_email_core');

const resendApiKey = defineSecret('RESEND_API_KEY');
const resendWebhookSecret = defineSecret('RESEND_WEBHOOK_SECRET');
const REGION = 'europe-west1';
const FROM = 'TBT <noreply@auth.trtbt.com>';
const REPLY_TO = 'info@trtbt.com';

function verificationTemplate({displayName, link}) {
  const safeName = escapeHtml(displayName || 'TBT kullanıcısı');
  const safeLink = escapeHtml(link);
  return {
    subject: 'TBT e-posta adresini doğrula',
    text: `Merhaba ${displayName || 'TBT kullanıcısı'},\n\nE-posta adresini doğrulamak için bağlantıyı aç:\n${link}\n\nBu hesabı sen oluşturmadıysan bu mesajı yok sayabilirsin.`,
    html: `<!doctype html><html lang="tr"><body style="margin:0;background:#07111f;font-family:Arial,sans-serif;color:#f8fafc"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#07111f;padding:32px 12px"><tr><td align="center"><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#0d1b2f;border:1px solid #263b57;border-radius:24px;padding:32px"><tr><td><div style="font-size:14px;font-weight:800;letter-spacing:2px;color:#57d9d0">TBT</div><h1 style="margin:16px 0 8px;font-size:28px;line-height:1.2;color:#fff">E-posta adresini doğrula</h1><p style="margin:0 0 22px;color:#cbd5e1;line-height:1.6">Merhaba ${safeName}, TBT hesabını kullanmaya devam etmek için e-posta adresini doğrula.</p><a href="${safeLink}" style="display:inline-block;background:#57d9d0;color:#07111f;text-decoration:none;font-weight:800;padding:14px 22px;border-radius:14px">E-postamı doğrula</a><p style="margin:24px 0 0;color:#94a3b8;font-size:13px;line-height:1.5">Bu hesabı sen oluşturmadıysan bu mesajı yok sayabilirsin.</p></td></tr></table></td></tr></table></body></html>`,
  };
}

async function reserveSend(db, {uid, emailHash, ip}, nowMs) {
  const keys = [
    {key: `uid:${uid}`, options: {hourLimit: 5, dayLimit: 20}},
    {key: `email:${emailHash}`, options: {hourLimit: 5, dayLimit: 20}},
    {key: `ip:${ip || 'unknown'}`, options: {minIntervalMs: 5000, hourLimit: 20, dayLimit: 60}},
  ];
  return db.runTransaction(async (tx) => {
    const refs = keys.map(({key}) => db.collection('verification_email_limits')
      .doc(createHash('sha256').update(key).digest('hex')));
    const snapshots = await Promise.all(refs.map((ref) => tx.get(ref)));
    const decisions = snapshots.map((snapshot, index) =>
      rateDecision(snapshot.data(), nowMs, keys[index].options));
    const blocked = decisions.find((decision) => !decision.allowed);
    if (blocked) {
      throw new HttpsError(
        'resource-exhausted',
        `${blocked.retryAfterSeconds} saniye sonra tekrar deneyebilirsin.`,
        {retryAfterSeconds: blocked.retryAfterSeconds},
      );
    }
    refs.forEach((ref, index) => tx.set(
      ref,
      {...decisions[index].next, updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
    ));
    return decisions[0];
  });
}

exports.sendVerificationEmail = onCall({
  region: REGION,
  timeoutSeconds: 30,
  maxInstances: 10,
  secrets: [resendApiKey],
}, async (request) => {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş gerekli.');
  const apiKey = String(resendApiKey.value() || '').trim();
  if (!apiKey) throw new HttpsError('failed-precondition', 'E-posta servisi yapılandırılmadı.');

  const uid = request.auth.uid;
  const auth = getAuth();
  const db = getFirestore();
  const account = await auth.getUser(uid);
  if (account.disabled || !account.email) {
    throw new HttpsError('failed-precondition', 'Bu hesap için doğrulanabilir bir e-posta bulunamadı.');
  }
  if (account.emailVerified) return {ok: true, alreadyVerified: true};

  const nowMs = Date.now();
  const emailHash = createHash('sha256').update(account.email.toLowerCase()).digest('hex');
  const rate = await reserveSend(db, {
    uid,
    emailHash,
    ip: String(request.rawRequest?.ip || 'unknown'),
  }, nowMs);
  const logRef = db.collection('verification_email_deliveries').doc();
  const baseLog = {
    uid,
    emailHash,
    maskedEmail: maskEmail(account.email),
    provider: 'resend',
    status: 'preparing',
    requestId: logRef.id,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  await logRef.set(baseLog);

  let response;
  let body = {};
  try {
    const link = await auth.generateEmailVerificationLink(account.email);
    const template = verificationTemplate({displayName: account.displayName, link});
    response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': `tbt-verification-${logRef.id}`,
      },
      body: JSON.stringify({
        from: FROM,
        to: [account.email],
        reply_to: REPLY_TO,
        subject: template.subject,
        text: template.text,
        html: template.html,
        tags: [{name: 'type', value: 'email_verification'}],
      }),
      signal: AbortSignal.timeout(12000),
    });
    body = await response.json().catch(() => ({}));
  } catch (error) {
    await logRef.set({
      status: 'failed',
      errorCode: ['TimeoutError', 'AbortError'].includes(error?.name) ? 'timeout' : 'transport',
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    throw new HttpsError('unavailable', 'Doğrulama e-postası şu anda gönderilemedi. Tekrar dene.');
  }

  if (!response.ok || typeof body.id !== 'string' || !body.id) {
    await logRef.set({
      status: 'failed',
      errorCode: `provider_${response.status}`,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    throw new HttpsError('unavailable', 'Doğrulama e-postası şu anda gönderilemedi. Tekrar dene.');
  }

  await Promise.all([
    logRef.set({
      status: 'accepted',
      providerMessageId: body.id,
      acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
    db.collection('users').doc(uid).set({
      emailVerificationLastSentAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true}),
  ]);
  return {ok: true, status: 'accepted', retryAfterSeconds: rate.retryAfterSeconds};
});

exports.resendVerificationEmailWebhook = onRequest({
  region: REGION,
  timeoutSeconds: 20,
  maxInstances: 10,
  secrets: [resendWebhookSecret],
}, async (request, response) => {
  if (request.method !== 'POST') return response.status(405).send('Method Not Allowed');
  const rawBody = request.rawBody;
  const valid = verifyWebhookSignature({
    secret: resendWebhookSecret.value(),
    id: request.get('svix-id'),
    timestamp: request.get('svix-timestamp'),
    signature: request.get('svix-signature'),
    payload: rawBody,
  });
  if (!valid) return response.status(401).send('Invalid signature');

  let event;
  try {
    event = JSON.parse(rawBody.toString('utf8'));
  } catch (_) {
    return response.status(400).send('Invalid JSON');
  }
  const status = webhookStatus(event.type);
  const providerMessageId = String(event.data?.email_id || '');
  if (!status || !providerMessageId) return response.status(200).send('Ignored');

  const db = getFirestore();
  const eventKey = createHash('sha256').update(String(event.id || request.get('svix-id'))).digest('hex');
  const eventRef = db.collection('verification_email_webhook_events').doc(eventKey);
  if ((await eventRef.get()).exists) return response.status(200).send('Duplicate');
  const matching = await db.collection('verification_email_deliveries')
    .where('providerMessageId', '==', providerMessageId).limit(1).get();
  const batch = db.batch();
  batch.create(eventRef, {
    provider: 'resend',
    providerMessageId,
    type: String(event.type),
    createdAt: FieldValue.serverTimestamp(),
  });
  if (!matching.empty) {
    const update = {
      status,
      providerEventType: String(event.type),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (status === 'delivered') update.deliveredAt = FieldValue.serverTimestamp();
    if (['failed', 'bounced', 'complained', 'suppressed'].includes(status)) {
      update.failedAt = FieldValue.serverTimestamp();
    }
    batch.set(matching.docs[0].ref, update, {merge: true});
  }
  await batch.commit();
  return response.status(200).send('OK');
});
