const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {FieldValue} = require('firebase-admin/firestore');

// Longer than the longest callable timeout (540s). A timed-out worker cannot
// still be running when another request takes over its lease.
const LEASE_MS = 12 * 60 * 1000;
function assertRestorable(profile) {
  if (!profile || profile.disabled === true || profile.banned === true ||
      !['active', 'frozen'].includes(profile.accountStatus ?? 'active')) {
    throw new HttpsError('permission-denied', 'Bu hesabın durumu değiştirilemez.');
  }
}

async function withAccountLifecycle({db, auth, uid, operation, afterActivate}, work) {
  if (!['freeze', 'unfreeze', 'delete'].includes(operation)) throw Error('Invalid lifecycle operation');
  if (operation !== 'delete') {
    const account = await auth.getUser(uid);
    if (account.disabled) throw new HttpsError('permission-denied', 'Hesap kullanılamıyor.');
  }
  const userRef = db.collection('users').doc(uid);
  const lockRef = db.collection('account_lifecycle_locks').doc(uid);
  const token = randomUUID();
  const initial = await db.runTransaction(async tx => {
    const [user, lock] = await Promise.all([tx.get(userRef), tx.get(lockRef)]);
    if (Number(lock.data()?.expiresAtMs || 0) > Date.now()) {
      throw new HttpsError('aborted', 'Başka bir hesap işlemi sürüyor. Biraz sonra tekrar dene.');
    }
    if (operation !== 'delete') {
      if (!user.exists) throw new HttpsError('not-found', 'Hesap bulunamadı.');
      assertRestorable(user.data());
    }
    tx.set(lockRef, {token, operation, expiresAtMs: Date.now() + LEASE_MS});
    // Publish restrictive state before processing potentially many content pages.
    if (operation === 'freeze' || operation === 'delete') {
      tx.set(userRef, {
        accountStatus: operation === 'freeze' ? 'frozen' : 'deleting',
        ...(operation === 'freeze' ? {frozenAt: FieldValue.serverTimestamp()} : {}),
        accountStatusUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return user.data();
  });
  try {
    const result = await work(initial);
    if (operation === 'unfreeze' && initial.accountStatus === 'frozen') {
      // Recheck both Auth and Firestore: an administrator may restrict the
      // account while the content update is in flight. Never overwrite that.
      if ((await auth.getUser(uid)).disabled) {
        throw new HttpsError('permission-denied', 'Hesap kullanılamıyor.');
      }
      await db.runTransaction(async tx => {
        const [user, lock] = await Promise.all([tx.get(userRef), tx.get(lockRef)]);
        if (lock.data()?.token !== token) throw new HttpsError('aborted', 'Hesap işlemi değişti.');
        assertRestorable(user.data());
        if (user.data().accountStatus !== 'frozen') throw new HttpsError('aborted', 'Hesap durumu değişti.');
        tx.set(userRef, {accountStatus: 'active', frozenAt: FieldValue.delete(),
          accountStatusUpdatedAt: FieldValue.serverTimestamp()}, {merge: true});
      });
    }
    if (operation === 'unfreeze' && afterActivate) await afterActivate();
    return result;
  } finally {
    await db.runTransaction(async tx => {
      const lock = await tx.get(lockRef);
      if (lock.data()?.token === token) tx.delete(lockRef);
    });
  }
}

module.exports = {withAccountLifecycle, LEASE_MS};
