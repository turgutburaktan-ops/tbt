const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore} = require('firebase-admin/firestore');

exports.resolveUsernameForLogin = onCall({region: 'europe-west1'}, async (request) => {
  const username = String(request.data?.username || '')
    .trim()
    .replace(/^@/, '')
    .toLowerCase()
    .slice(0, 30);
  if (!/^[a-z0-9_.]+$/.test(username)) {
    throw new HttpsError('invalid-argument', 'Kullanıcı adı veya şifre hatalı.');
  }
  const db = getFirestore();
  const reservation = await db.collection('usernames').doc(username).get();
  const uid = String(reservation.data()?.uid || '');
  if (!uid) throw new HttpsError('not-found', 'Kullanıcı adı veya şifre hatalı.');
  const user = await db.collection('users').doc(uid).get();
  const email = String(user.data()?.email || '').trim();
  if (!email) throw new HttpsError('not-found', 'Kullanıcı adı veya şifre hatalı.');
  return {email};
});
