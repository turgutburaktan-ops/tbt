function normalizeUsername(value) {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/^@/, '').replaceAll('İ', 'i').toLowerCase()
    .replace(/[ıçğöşü]/g, ch => ({ı:'i', ç:'c', ğ:'g', ö:'o', ş:'s', ü:'u'}[ch]));
}
function validUsername(value) {
  return /^[a-z0-9_][a-z0-9_.]{1,28}[a-z0-9_]$/.test(value) && !value.includes('..');
}
module.exports = {normalizeUsername, validUsername};
