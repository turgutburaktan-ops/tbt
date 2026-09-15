const provinces = require('./provinces.json');
const kinds = ['gezi', 'dining', 'cafe', 'hotel'];
const text = v => typeof v === 'string' ? v.trim() : '';
const fold = v => text(v).toLocaleLowerCase('tr-TR').normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '').replace(/ı/g, 'i').replace(/[^a-z0-9]+/g, ' ').trim();
const cityName = v => provinces.find(n => fold(n) === fold(v)) || null;
const cityKey = v => { const city = cityName(v); return city ? fold(city).replace(/ /g, '_') : null; };
const partition = (city, kind) => cityKey(city) && kinds.includes(kind) ? `${cityKey(city)}_${kind}` : null;
const coordinate = v => typeof v === 'number' && Number.isFinite(v);
const validPosition = d => coordinate(d.latitude) && coordinate(d.longitude) &&
  d.latitude >= 35.4 && d.latitude <= 42.3 && d.longitude >= 25.4 && d.longitude <= 45.1;
const publicUrl = v => { try { const u = new URL(text(v)); return u.protocol === 'https:' && !u.username && !u.password ? u.href : ''; } catch (_) { return ''; } };
function spotRow(id, d) {
  if (!d || d.status !== 'published' || d.coordinateVerified !== true || d.imageVerified !== true ||
      !validPosition(d) || !text(d.name) || !cityName(d.city) || !publicUrl(d.imageUrl)) return null;
  const row = {schemaVersion: 1, canonicalId: `spot:${id}`, legacyId: id, kind: 'gezi',
    city: cityName(d.city), cityKey: cityKey(d.city), district: text(d.district),
    name: text(d.name), nameKey: fold(d.name), latitude: d.latitude, longitude: d.longitude,
    category: text(d.category) || 'Genel', imageUrl: publicUrl(d.imageUrl),
    rating: Math.min(5, Math.max(0, Number(d.rating) || 0)), source: text(d.sourceType) || 'photo_spots',
    status: 'published', coordinateVerified: true, imageVerified: true,
    tags: Array.isArray(d.tags) ? d.tags.filter(t => typeof t === 'string') : []};
  for (const key of ['description','bestTime','angle','recommendedLens','difficulty','imageAuthor','imageLicense']) row[key] = text(d[key]);
  for (const key of ['imageOriginalUrl','imageSourcePage']) row[key] = publicUrl(d[key]);
  return row;
}
function venueRow(key, external, business, excluded = false) {
  const approved = business?.verified === true && business.pendingListing !== true &&
    !['hidden','rejected','deleted','suspended'].includes(business.listingStatus);
  if (excluded && !approved) return null;
  const d = approved ? {...external, ...business,
    venueName: business.venueName || external?.venueName,
    city: cityName(business.province) || cityName(business.city) || external?.city,
    latitude: business.latitude ?? external?.latitude,
    longitude: business.longitude ?? external?.longitude} : external;
  if (!d || (!approved && d.status !== 'published') || !validPosition(d)) return null;
  const kind = text(d.category), id = text(d.venueId) || key.substring(key.indexOf(':') + 1);
  const city = cityName(d.province) || cityName(d.city);
  const name = text(d.venueName) || text(d.name);
  if (!kinds.slice(1).includes(kind) || !city || !name || !id || id.includes('/') || key !== `${kind}:${id}`) return null;
  return {schemaVersion: 1, canonicalId: `venue:${kind}:${id}`, legacyId: id, kind,
    city, cityKey: cityKey(city), district: text(d.district), name, nameKey: fold(name),
    latitude: d.latitude, longitude: d.longitude, category: kind,
    imageUrl: publicUrl(d.coverImageUrl || d.imageUrl || d.photoUrl || d.logoUrl),
    description: text(d.shortDescription || d.description), address: text(d.address),
    openingHours: text(d.openingHours), phone: text(d.phone), website: publicUrl(d.website),
    managed: approved, source: approved ? 'approved_business' : (d.source === 'overture' ? 'overture' : 'openstreetmap'),
    sourceUrl: publicUrl(d.sourceUrl), attribution: approved ? '' : (d.source === 'overture' ? 'Overture Maps Foundation · CDLA Permissive 2.0 / Apache 2.0 · https://docs.overturemaps.org/attribution/' : '© OpenStreetMap contributors · ODbL'),
    rating: Math.min(5, Math.max(0, Number(d.rating) || 0)),
    routeRecommended: d.routeSettings?.enabled === true};
}
function meters(a, b) {
  const rad = x => x * Math.PI / 180;
  const h = Math.sin(rad(b.latitude-a.latitude)/2)**2 + Math.cos(rad(a.latitude))*Math.cos(rad(b.latitude))*Math.sin(rad(b.longitude-a.longitude)/2)**2;
  return 12742000 * Math.asin(Math.sqrt(Math.min(1, h)));
}
module.exports = {provinces, kinds, text, fold, cityName, cityKey, partition, validPosition, publicUrl, spotRow, venueRow, meters};
