const MESSAGE_TYPES = new Set(['message', 'group_message']);

function preferenceKeyForType(rawType) {
  const type = String(rawType || '').trim().toLowerCase();
  if (!type) return null;
  if (MESSAGE_TYPES.has(type)) return 'messages';
  if (type.endsWith('_like') || type === 'like') return 'likes';
  if (type.includes('comment') || type.endsWith('_reply')) return 'comments';
  if (
    type.startsWith('business_reservation') ||
    type.startsWith('business_preparation') ||
    type.startsWith('reservation_')
  ) return 'reservations';
  if (
    type.startsWith('event_') ||
    type.startsWith('social_event_') ||
    type === 'business_event' ||
    type === 'community_event' ||
    type === 'campus_digest'
  ) return 'events';
  if (
    type === 'reengagement' ||
    type === 'retention' ||
    type === 'nearby_recommendation' ||
    type === 'weekly_digest'
  ) return 'recommendations';
  if (
    type === 'tbt_broadcast' ||
    type === 'business_campaign' ||
    type === 'business_announcement'
  ) return 'marketing';
  if (
    type === 'follow' ||
    type.includes('mention') ||
    type.includes('tag') ||
    type.startsWith('story_')
  ) return 'social';
  return null;
}

function pushPreferenceAllowed(user, rawType) {
  const data = user || {};
  if (data.notificationsEnabled === false || data.settings?.notifyPush === false) {
    return false;
  }

  const key = preferenceKeyForType(rawType);
  if (!key) return true;
  const preferences = data.notificationPreferences || {};

  // Promotional messages are opt-in. Product and transactional notifications
  // remain enabled for existing accounts until the user explicitly opts out.
  if (key === 'marketing') {
    return preferences.marketing === true && data.settings?.notifyMarketing !== false;
  }
  if (key === 'recommendations') {
    return preferences.recommendations !== false &&
      data.pushReengagementEnabled !== false &&
      data.retentionNotificationsEnabled !== false;
  }
  if (key === 'reservations') {
    return preferences.reservations !== false && preferences.events !== false;
  }
  return preferences[key] !== false;
}

module.exports = {preferenceKeyForType, pushPreferenceAllowed};
