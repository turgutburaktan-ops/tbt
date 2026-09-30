// Add explicit queryable visibility without ever thawing a frozen post.
async function backfillPost({db, ref, apply = false}) {
  return db.runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return 'deleted';
    const post = snapshot.data();
    if (typeof post.userId !== 'string' || !post.userId || post.userId.includes('/')) return 'invalid-owner';
    const owner = (await tx.get(db.doc(`users/${post.userId}`))).data();
    const frozen = post.accountFrozen === true || !owner ||
      (owner.accountStatus || 'active') !== 'active' || owner.banned === true || owner.disabled === true;
    if (post.accountFrozen === frozen) return 'unchanged';
    if (apply) tx.update(ref, {accountFrozen:frozen});
    return frozen ? 'hide' : 'make-queryable';
  });
}
module.exports = {backfillPost};
