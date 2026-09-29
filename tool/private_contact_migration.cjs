const CONTACT_FIELDS = ['email', 'phoneNumber', 'verifiedPhoneNumber'];

// Both reads and both writes belong to the same transaction. An already private
// value is authoritative, including an intentional null/empty value.
async function migrateContactRecord({db, publicRef, privateRef, fieldValue}) {
  return db.runTransaction(async tx => {
    const [profile, privateProfile] = await Promise.all([tx.get(publicRef), tx.get(privateRef)]);
    if (!profile.exists) return false;
    const publicData = profile.data() || {};
    const privateData = privateProfile.data() || {};
    const copy = {}, remove = {};
    for (const field of CONTACT_FIELDS) {
      if (!Object.hasOwn(publicData, field)) continue;
      if (!Object.hasOwn(privateData, field)) copy[field] = publicData[field];
      remove[field] = fieldValue.delete();
    }
    if (!Object.keys(remove).length) return false;
    tx.set(privateRef, {...copy, migratedAt: fieldValue.serverTimestamp()}, {merge: true});
    tx.update(publicRef, remove);
    return true;
  });
}
module.exports = {CONTACT_FIELDS, migrateContactRecord};
