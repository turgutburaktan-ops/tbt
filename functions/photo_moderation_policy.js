const LEVELS = ['UNKNOWN', 'VERY_UNLIKELY', 'UNLIKELY', 'POSSIBLE', 'LIKELY', 'VERY_LIKELY'];
function classify(scores) {
  if (!scores || !LEVELS.includes(scores.adult) || scores.adult === 'UNKNOWN' ||
      !LEVELS.includes(scores.racy) || scores.racy === 'UNKNOWN') throw Error('incomplete_safe_search');
  // Racy alone includes swimwear: never automatically remove or count it.
  if (scores.adult === 'VERY_LIKELY' && !['LIKELY', 'VERY_LIKELY'].includes(scores.medical)) return 'hide';
  if (LEVELS.indexOf(scores.adult) >= 3 || LEVELS.indexOf(scores.racy) >= 4) return 'review';
  return 'clear';
}
function ownedPaths(post) {
  const prefix = `users/${post.userId}/`;
  return [...new Set(['storagePath', 'thumbnailStoragePath', 'videoStoragePath', 'originalVideoStoragePath']
    .map(k => post[k]).filter(p => typeof p === 'string' && p.startsWith(prefix) && !p.includes('..')))];
}
function photoPath(post, bucket) {
  const path = post.storagePath;
  if (!ownedPaths(post).includes(path) || !/\.(jpe?g|png|webp|heic|heif)$/i.test(path)) throw Error('invalid_photo_path');
  const url = new URL(post.imageUrl);
  if (url.origin !== 'https://firebasestorage.googleapis.com' ||
      url.pathname !== `/v0/b/${bucket}/o/${encodeURIComponent(path)}`) throw Error('photo_url_mismatch');
  return path;
}
function strikeChange(previous, next) { return Number(next === 'confirmed') - Number(previous === 'confirmed'); }
function closureStatus(count, previous, delta) {
  if (['closing','closed','reopening'].includes(previous)) return previous;
  if (count < 5) return 'none';
  return delta > 0 ? 'pending' : previous || 'pending';
}
module.exports = {classify, ownedPaths, photoPath, strikeChange, closureStatus};
