// Keep this contract aligned with lib/services/published_spot_catalog.dart.
export const text = value => typeof value === 'string' ? value.trim() : '';
const number = value => {
  if (typeof value !== 'number' && (typeof value !== 'string' || !value.trim())) return null;
  if (typeof value === 'string' && !/^[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?$/i.test(value.trim())) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
};
export function decodeSpot(id, data) {
  if (data.status !== 'published' || data.coordinateVerified !== true || data.imageVerified !== true) return null;
  const name = text(data.name), city = text(data.city);
  const lat = number(data.latitude), lng = number(data.longitude), imageUrl = text(data.imageUrl);
  let image;
  try { image = new URL(imageUrl); } catch { return null; }
  if (!id || !name || !city || lat === null || lng === null ||
      lat < 35.4 || lat > 42.3 || lng < 25.4 || lng > 45.1 ||
      image.protocol !== 'https:' || !image.hostname || image.username || image.password) return null;
  return {
    id, name, city, lat, lng, imageUrl, image: previewUrl(imageUrl),
    category: text(data.category) || 'Genel', best: text(data.bestTime),
    district: text(data.district), description: text(data.description),
    rating: Math.min(5, Math.max(0, number(data.rating) ?? 0)),
    tags: [...new Set(['FirestoreDoğrulanmış', text(data.district),
      ...(Array.isArray(data.tags) ? data.tags.filter(x => typeof x === 'string' && x.trim()) : [])].filter(Boolean))],
  };
}

export function previewUrl(value) {
  const url = new URL(value);
  if (url.hostname === 'commons.wikimedia.org' && /Special:(?:FilePath|Redirect\/file)\//i.test(url.pathname.replace(/%3a/ig, ':'))) {
    url.searchParams.set('width', '500');
    return url.href;
  }
  if (url.hostname === 'upload.wikimedia.org' || url.hostname === 'thumb.wikimedia.org') {
    const match = url.pathname.match(/^\/wikipedia\/commons\/(?:thumb\/)?([a-f0-9]\/[^/]+\/([^/]+))(?:\/[^/]+)?$/);
    if (match && /\.(jpe?g|png|webp)$/i.test(match[2])) {
      url.pathname = `/wikipedia/commons/thumb/${match[1]}/500px-${match[2]}`;
      return url.href;
    }
  }
  return value;
}

export const nameKey = value => value.replaceAll('İ', 'i').toLowerCase()
  .replaceAll('ı', 'i').replaceAll('ş', 's').replaceAll('ğ', 'g')
  .replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ç', 'c')
  .replace(/[^a-z0-9]+/g, ' ').trim();
const meters = (a, b) => {
  const k = Math.PI / 180;
  const h = Math.sin((b.lat-a.lat)*k/2)**2 + Math.cos(a.lat*k)*Math.cos(b.lat*k)*Math.sin((b.lng-a.lng)*k/2)**2;
  return 12742000 * Math.asin(Math.sqrt(Math.max(0, Math.min(1, h))));
};
export function filterSpots(input) {
  const sorted = [...input].sort((a,b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  const ids = new Set(), names = new Set(), cells = new Map(), result = [];
  for (const spot of sorted) {
    const name = nameKey(spot.name);
    if (ids.has(spot.id) || names.has(name)) continue;
    const x = Math.floor(spot.lat*1000), y = Math.floor(spot.lng*1000);
    let duplicate = false;
    for (let dx=-1; dx<=1; dx++) for (let dy=-1; dy<=1; dy++) {
      if ((cells.get(`${x+dx}:${y+dy}`)||[]).some(other => meters(spot,other)<=18)) duplicate = true;
    }
    if (duplicate) continue;
    ids.add(spot.id); names.add(name); result.push(spot);
    const cell = `${x}:${y}`;
    if (!cells.has(cell)) cells.set(cell, []);
    cells.get(cell).push(spot);
  }
  return result;
}

function deadline(promise, ms) {
  let timer;
  return Promise.race([promise, new Promise((_,reject) => {
    timer=setTimeout(()=>reject(new Error('Gezilecek yerler alınamadı. Tekrar deneyebilirsin.')),ms);
  })]).finally(()=>clearTimeout(timer));
}

// readPage returns {docs:[{id,data}], cursor}, always ordered by document ID.
// Replace the cached list only after every page succeeds, including [] after
// removals. A failed page must never publish a partially loaded catalog.
export function createSpotCatalog(readPage, {now=Date.now, ttl=300000, timeout=10000}={}) {
  let cached=null, savedAt=0, running=null;
  const load=async()=>{
    const rows=[];
    let cursor=null;
    while (true) {
      const page=await deadline(readPage(cursor,500),timeout);
      rows.push(...page.docs.map(d=>decodeSpot(d.id,d.data)).filter(Boolean));
      if (page.docs.length<500) break;
      if (!page.cursor || page.cursor===cursor) throw new Error('Katalog sayfalaması ilerlemedi.');
      cursor=page.cursor;
    }
    cached=filterSpots(rows); savedAt=now(); return cached;
  };
  return {
    async load({refresh=false}={}) {
      if (!refresh && cached!==null && now()-savedAt<ttl) return cached;
      if (!running) running=load().catch(error=>{
        if (cached!==null) return cached;
        throw error;
      }).finally(()=>{running=null;});
      return running;
    },
  };
}
