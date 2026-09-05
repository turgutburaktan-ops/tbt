const ADMIN_EMAIL = 'turgutburaktan@gmail.com';

function isNamedAdmin(auth) {
  return Boolean(auth?.uid && auth.token?.admin === true &&
    auth.token?.email_verified === true &&
    String(auth.token?.email || '').toLowerCase() === ADMIN_EMAIL);
}

function marketingPushAllowed(user) {
  return user?.notificationPreferences?.marketing === true &&
    user?.settings?.notifyMarketing !== false;
}

module.exports = {isNamedAdmin, marketingPushAllowed};
