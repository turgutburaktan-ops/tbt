const {FieldValue} = require('firebase-admin/firestore');
const {provinces, partition, validPosition, meters, fold} = require('./schema');
const {project} = require('./store');
const filters = {
  cafe: ['["amenity"~"^(cafe|ice_cream|juice_bar)$"]','["shop"~"^(coffee|pastry|confectionery|tea|chocolate)$"]'],
  dining: ['["amenity"~"^(restaurant|fast_food|food_court|bar|pub|biergarten|bbq)$"]','["shop"~"^(bakery|deli|butcher|seafood|cheese|pasta|convenience)$"]'],
  hotel: ['["tourism"~"^(hotel|hostel|guest_house|motel|apartment|chalet|resort|camp_site|caravan_site)$"]'],
};
function query(city, kind) {
  const index = provinces.indexOf(city);
  if (index < 0 || !filters[kind]) throw Error('Unknown catalog partition');
  const iso = `TR-${String(index+1).padStart(2,'0')}`;
  return `[out:json][timeout:40];area["ISO3166-2"="${iso}"]["admin_level"="4"]->.p;.p out ids;(${filters[kind].map(f=>`nwr(area.p)${f}["name"];`).join('')});out center tags;`;
}
function decode(body, city, kind) {
  if (!body || body.remark || !Array.isArray(body.elements) || !body.elements.some(e=>e.type==='area')) throw Error('Incomplete upstream response');
  const rows = [], names = new Map();
  for (const item of body.elements) {
    const t = item.tags || {};
    const name = String(t['name:tr'] || t.name || '').trim();
    const latitude = item.lat ?? item.center?.lat, longitude = item.lon ?? item.center?.lon;
    if (!['node','way','relation'].includes(item.type) || !Number.isSafeInteger(item.id) || !name || !validPosition({latitude,longitude})) continue;
    const row = {venueId: `${item.type}-${item.id}`, venueName: name, category: kind, city,
      district: String(t['addr:district'] || t['addr:suburb'] || ''), latitude, longitude,
      address: [t['addr:street'],t['addr:housenumber'],t['addr:district'],city].filter(Boolean).join(', '),
      openingHours: String(t.opening_hours || ''), phone: String(t['contact:phone'] || t.phone || ''),
      website: String(t['contact:website'] || t.website || ''), description: String(t['description:tr'] || t.description || ''),
      sourceUrl: `https://www.openstreetmap.org/${item.type}/${item.id}`, status: 'published', source: 'openstreetmap'};
    // Do not import unlicensed photographs. Preserve established OSM identifiers.
    const nameKey = fold(name), sameName = names.get(nameKey) || [];
    if (!sameName.some(other=>meters(other,row)<18)) {
      rows.push(row);sameName.push(row);names.set(nameKey,sameName);
    }
  }
  return rows;
}
async function refreshPartition(db, city, kind, fetcher = fetch, {projectInline = true} = {}) {
  const meta = db.doc(`place_catalog/${partition(city,kind)}`);
  await meta.set({sourceStatus:'updating',sourceAttemptAt:FieldValue.serverTimestamp()}, {merge:true});
  let rows, lastError;
  for (const base of ['https://overpass.kumi.systems/api/interpreter','https://overpass-api.de/api/interpreter']) {
    try {
      const response = await fetcher(`${base}?${new URLSearchParams({data:query(city,kind)})}`, {
        headers: {'User-Agent':'TBT-catalog/1.0 (server sync)','Accept':'application/json'}, signal:AbortSignal.timeout(50000)});
      if (!response.ok) throw Error(`upstream_${response.status}`);
      rows = decode(await response.json(),city,kind);
      // Empty/intermittent responses never replace a previously working catalog.
      if (!rows.length) throw Error('empty_source_response');
      break;
    } catch(e) { rows = null; lastError = e; }
  }
  if (!rows) {
    await meta.set({sourceStatus:'unavailable',sourceError:String(lastError?.message || 'unavailable').slice(0,150)}, {merge:true});
    return {ok:false,city,kind,count:0};
  }
  for (let offset = 0; offset < rows.length; offset += 200) {
    const chunk = rows.slice(offset, offset + 200), batch = db.batch();
    for (const row of chunk) batch.set(db.doc(`catalog_external_venues/${kind}:${row.venueId}`),
      {...row,seenAt:FieldValue.serverTimestamp()}, {merge:true});
    await batch.commit();
    // Scheduled refresh persists all rows quickly; retryable document triggers
    // project them durably. The initial migration can await projection explicitly.
    if (projectInline) for (const row of chunk) await project(db,'venue',`${kind}:${row.venueId}`);
  }
  await meta.set({sourceStatus:'ready',lastSourceSuccessAt:FieldValue.serverTimestamp(),lastSourceCount:rows.length,sourceError:FieldValue.delete()}, {merge:true});
  return {ok:true,city,kind,count:rows.length};
}
module.exports = {query, decode, refreshPartition};
