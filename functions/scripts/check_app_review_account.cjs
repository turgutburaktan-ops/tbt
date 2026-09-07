'use strict';

const admin = require('firebase-admin');

async function main() {
  const credential = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  if (credential.project_id !== 'en-iyi-cekim-noktasi') {
    throw new Error('Unexpected Firebase project');
  }
  const app = admin.initializeApp({credential: admin.credential.cert(credential)});
  try {
    const username = 'snnayra23';
    const reservation = await app.firestore().collection('usernames').doc(username).get();
    if (!reservation.exists) {
      throw new Error('App Review username reservation is missing');
    }
    const uid = reservation.data()?.uid;
    if (typeof uid !== 'string' || !uid) {
      throw new Error('App Review username reservation has no account');
    }
    const account = await app.auth().getUser(uid);
    if (account.disabled) {
      throw new Error('App Review account is disabled');
    }
    if (!account.email) {
      throw new Error('App Review account has no email sign-in identity');
    }
    console.log('App Review username reservation and enabled Firebase account passed.');
  } finally {
    await app.delete();
  }
}

main().catch(error => {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
});
