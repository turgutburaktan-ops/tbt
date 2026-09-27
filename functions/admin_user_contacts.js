const {getAuth} = require('firebase-admin/auth');

// Called only after the caller's admin guard. Auth remains authoritative after
// public-profile contact migration and subsequent email/phone changes.
async function adminUserEmails(uids, auth = getAuth()) {
  const unique = [...new Set(uids)];
  const emails = new Map();
  for (let offset = 0; offset < unique.length; offset += 100) {
    const result = await auth.getUsers(unique.slice(offset, offset + 100).map(uid => ({uid})));
    for (const user of result.users) emails.set(user.uid, user.email || '');
  }
  return emails;
}

module.exports = {adminUserEmails};
