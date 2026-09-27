// TBT venue awards. Business subscriptions and community roles are never inputs.
const DAY = 86400000;
const CRITERIA = ['quality', 'cleanliness', 'service', 'value', 'comfort'];
const WEIGHTS = Object.freeze({dining: [35, 20, 20, 15, 10], cafe: [30, 20, 20, 15, 15], hotel: [30, 25, 20, 15, 10]});
const LEVELS = [
  {level: 1, label: 'TBT Öneriyor', score: 80, count: 15, days: 30, floor: 0},
  {level: 2, label: 'TBT Seçkisi', score: 88, count: 40, days: 90, floor: 75},
  {level: 3, label: 'TBT İmzası', score: 94, count: 80, days: 180, floor: 85},
];
const ms = value => value?.toMillis?.() || Number(value) || 0;
function validScores(scores) {
  return scores && Object.keys(scores).length === CRITERIA.length && CRITERIA.every(k => Number.isInteger(scores[k]) && scores[k] >= 1 && scores[k] <= 5);
}
function eligibleProof(proof, now) {
  return proof && ['coupon', 'reservation', 'qr'].includes(proof.type) && ms(proof.at) > now - 365 * DAY && ms(proof.at) <= now;
}
function calculate(category, rows, now = Date.now()) {
  if (!WEIGHTS[category]) throw new Error('Unsupported venue category');
  const unique = new Map();
  for (const row of rows) {
    if (!row.userId || row.excluded || !validScores(row.scores) || !eligibleProof(row.proof, now)) continue;
    if (!unique.has(row.userId) || ms(row.updatedAt) > ms(unique.get(row.userId).updatedAt)) unique.set(row.userId, row);
  }
  const reviews = [...unique.values()];
  // Re-editing an old visit must not make it a fresh experience.
  const recent = reviews.filter(r => ms(r.proof.at) >= now - 90 * DAY);
  const older = reviews.filter(r => ms(r.proof.at) < now - 90 * DAY);
  const criteria = {};
  for (const key of CRITERIA) {
    const mean = group => group.reduce((sum, r) => sum + r.scores[key] * 20, 0) / group.length;
    criteria[key] = recent.length && older.length ? .6 * mean(recent) + .4 * mean(older) : reviews.length ? mean(reviews) : 0;
  }
  const score = CRITERIA.reduce((sum, k, i) => sum + criteria[k] * WEIGHTS[category][i] / 100, 0);
  const dates = reviews.map(r => ms(r.proof.at));
  const spanDays = dates.length ? Math.floor((Math.max(...dates) - Math.min(...dates)) / DAY) : 0;
  let candidate = 0;
  if (criteria.cleanliness >= 80 && recent.length >= 5) {
    for (const level of LEVELS) {
      if (score >= level.score && reviews.length >= level.count && spanDays >= level.days && CRITERIA.every(k => criteria[k] >= level.floor)) candidate = level.level;
    }
  }
  return {score, criteria, count: reviews.length, recentCount: recent.length, spanDays, candidate};
}
function lifecycle(previous, metrics, now) {
  const award = previous.award || 0;
  const belowSinceMs = award > metrics.candidate ? (previous.belowSinceMs || now) : 0;
  return {award, belowSinceMs, needsReview: Boolean(belowSinceMs && now - belowSinceMs >= 30 * DAY)};
}
module.exports = {DAY, CRITERIA, WEIGHTS, LEVELS, ms, validScores, eligibleProof, calculate, lifecycle};
