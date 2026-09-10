const ADMIN_EMAIL = 'turgutburaktan@gmail.com';
const {pushPreferenceAllowed} = require('./notification_policy');

function isNamedAdmin(auth) {
  return Boolean(auth?.uid && auth.token?.admin === true &&
    auth.token?.email_verified === true &&
    String(auth.token?.email || '').toLowerCase() === ADMIN_EMAIL);
}

function marketingPushAllowed(user) {
  return pushPreferenceAllowed(user, 'tbt_broadcast');
}

module.exports = {isNamedAdmin, marketingPushAllowed};
