// Failed metrics must stay unavailable, never become a misleading zero.
function insightsQueries() {
  const unavailable = [];
  async function read(key, operation, fallback = null) {
    try {
      return await operation();
    } catch (error) {
      unavailable.push(key);
      console.warn('Admin insights query failed', {key, code: String(error.code || 'unknown')});
      return fallback;
    }
  }
  return {read, unavailable};
}

function totalOrUnavailable(values) {
  return values.every(value => typeof value === 'number' && Number.isFinite(value))
    ? values.reduce((sum, value) => sum + value, 0) : null;
}

module.exports = {insightsQueries, totalOrUnavailable};
