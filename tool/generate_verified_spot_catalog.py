#!/usr/bin/env python3
"""Generate a 1000+ Turkey photo-spot catalog from direct Wikidata/Commons facts.

No fuzzy matching is used. Every generated record must have its own Wikidata
P625 coordinate and P18 image. Commons license and pixel dimensions are checked
before the record is promoted into the app catalog.
"""
from __future__ import annotations

import argparse
import html
import json
import math
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'lib/data'
BUILD = ROOT / 'build/spot_import'
PLACES = DATA / 'verified_travel_places_generated.dart'
EVIDENCE = DATA / 'spot_coordinate_verification_registry_generated.dart'
IMAGES = DATA / 'verified_travel_image_registry_generated.dart'
QUALITY = DATA / 'verified_travel_image_quality_generated.json'
REPORT = BUILD / 'wikidata_verified_catalog_report.json'

WDQS = 'https://query.wikidata.org/sparql'
COMMONS = 'https://commons.wikimedia.org/w/api.php'
UA = 'BestPhotoSpotCatalog/2.0 (https://github.com/turgutburaktan-ops/tbt)'
MIN_LAT, MAX_LAT = 35.4, 42.3
MIN_LNG, MAX_LNG = 25.4, 45.1

ROOT_CLASSES = OrderedDict([
    ('Q570116', 'Turistik Yer'),
    ('Q839954', 'Arkeolojik Alan'),
    ('Q23413', 'Kale'),
    ('Q33506', 'Müze'),
    ('Q12280', 'Köprü'),
    ('Q34038', 'Şelale'),
    ('Q35509', 'Mağara'),
    ('Q150784', 'Kanyon'),
    ('Q23397', 'Göl'),
    ('Q40080', 'Sahil'),
    ('Q8502', 'Dağ'),
    ('Q22698', 'Park'),
    ('Q174782', 'Meydan'),
    ('Q32815', 'Cami'),
    ('Q44613', 'Manastır'),
])
FREE_LICENSE = ('cc by', 'cc-by', 'cc by-sa', 'cc-by-sa', 'cc0', 'public domain', 'pd-', 'free art license', 'gfdl')
POINT_RE = re.compile(r'Point\(([-\d.]+)\s+([-\d.]+)\)')
PHOTO_RE = re.compile(r'PhotoSpot\((.*?)\n\s*\),', re.DOTALL)
TAG_RE = re.compile(r'<[^>]+>')


def get_json(url: str, params: dict[str, str], attempts: int = 6) -> dict:
    target = f"{url}?{urllib.parse.urlencode(params)}"
    last = None
    for attempt in range(attempts):
        req = urllib.request.Request(target, headers={'User-Agent': UA, 'Accept': 'application/json,*/*;q=0.8'})
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read().decode('utf-8'))
        except urllib.error.HTTPError as exc:
            last = exc
            if exc.code not in (429, 500, 502, 503, 504):
                raise
        except Exception as exc:
            last = exc
        if attempt + 1 < attempts:
            time.sleep(min(30, 2 ** attempt))
    raise RuntimeError(f'request failed: {target}: {last}')


def norm(value: str) -> str:
    value = value.replace('İ', 'I').replace('ı', 'i')
    value = unicodedata.normalize('NFKD', value)
    value = ''.join(ch for ch in value if not unicodedata.combining(ch))
    return re.sub(r'[^a-z0-9]+', '-', value.lower()).strip('-')


def ds(value: str) -> str:
    return value.replace('\\', '\\\\').replace("'", "\\'").replace('\n', ' ').strip()


def strip_html(value: str) -> str:
    return html.unescape(TAG_RE.sub('', value or '')).strip()


def point(value: str) -> tuple[float, float] | None:
    m = POINT_RE.fullmatch(value.strip())
    if not m:
        return None
    lng, lat = float(m.group(1)), float(m.group(2))
    if MIN_LAT <= lat <= MAX_LAT and MIN_LNG <= lng <= MAX_LNG:
        return lat, lng
    return None


def distance_m(a: dict, b: dict) -> float:
    r = 6371000.0
    p1, p2 = math.radians(a['lat']), math.radians(b['lat'])
    dp = math.radians(b['lat'] - a['lat'])
    dl = math.radians(b['lng'] - a['lng'])
    h = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2*r*math.asin(math.sqrt(h))


def existing_places() -> list[dict]:
    out = []
    for path in sorted(DATA.glob('verified_travel_places*.dart')):
        if path == PLACES:
            continue
        text = path.read_text(encoding='utf-8')
        for body in PHOTO_RE.findall(text):
            def s(name):
                m = re.search(rf"{name}:\s*'([^']+)'", body)
                return m.group(1) if m else ''
            def n(name):
                m = re.search(rf'{name}:\s*(-?\d+(?:\.\d+)?)', body)
                return float(m.group(1)) if m else None
            if s('id') and s('name') and n('latitude') is not None and n('longitude') is not None:
                out.append({'id': s('id'), 'name': s('name'), 'city': s('city'), 'lat': n('latitude'), 'lng': n('longitude'), 'name_key': norm(s('name')), 'city_key': norm(s('city'))})
    return out


def query_for_root(root: str, limit: int, offset: int) -> str:
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image ?admin ?adminLabel WHERE {{
  ?item wdt:P17 wd:Q43 ; wdt:P625 ?coord ; wdt:P18 ?image ; wdt:P31 ?class .
  ?class wdt:P279* wd:{root} .
  OPTIONAL {{ ?item wdt:P131 ?admin . }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?item LIMIT {limit} OFFSET {offset}'''


def heritage_query(limit: int, offset: int) -> str:
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image ?admin ?adminLabel WHERE {{
  ?item wdt:P17 wd:Q43 ; wdt:P625 ?coord ; wdt:P18 ?image ; wdt:P1435 ?heritage .
  OPTIONAL {{ ?item wdt:P131 ?admin . }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?item LIMIT {limit} OFFSET {offset}'''


def collect_query(query_builder, category: str, page_size: int, max_rows: int, out: dict[str, dict]) -> None:
    offset = 0
    while offset < max_rows:
        limit = min(page_size, max_rows-offset)
        payload = get_json(WDQS, {'query': query_builder(limit, offset), 'format': 'json'})
        rows = payload.get('results', {}).get('bindings', [])
        if not rows:
            break
        for row in rows:
            uri = row.get('item', {}).get('value', '')
            qid = uri.rsplit('/', 1)[-1]
            p = point(row.get('coord', {}).get('value', ''))
            name = row.get('itemLabel', {}).get('value', '').strip()
            image = row.get('image', {}).get('value', '').strip()
            city = row.get('adminLabel', {}).get('value', '').strip() or 'Türkiye'
            if qid.startswith('Q') and p and name and image and qid not in out:
                out[qid] = {'qid': qid, 'name': name, 'city': city, 'lat': p[0], 'lng': p[1], 'image': image, 'category': category}
        offset += len(rows)
        if len(rows) < limit:
            break
        time.sleep(.35)


def wikidata_candidates(page_size: int, per_source_limit: int) -> dict[str, dict]:
    out: dict[str, dict] = {}
    collect_query(heritage_query, 'Kültür Mirası', page_size, per_source_limit, out)
    print(f'heritage unique: {len(out)}')
    for root, category in ROOT_CLASSES.items():
        collect_query(lambda limit, offset, r=root: query_for_root(r, limit, offset), category, page_size, per_source_limit, out)
        print(f'{root} {category}: unique total {len(out)}')
    return out


def filename(url: str) -> str:
    return urllib.parse.unquote(urllib.parse.urlparse(url).path.rsplit('/', 1)[-1]).replace('_', ' ')


def commons_meta(candidates: dict[str, dict]) -> None:
    title_map: dict[str, list[str]] = {}
    for qid, item in candidates.items():
        title_map.setdefault('File:' + filename(item['image']), []).append(qid)
    titles = sorted(title_map)
    for i in range(0, len(titles), 40):
        batch = titles[i:i+40]
        payload = get_json(COMMONS, {'action': 'query', 'format': 'json', 'formatversion': '2', 'prop': 'imageinfo', 'iiprop': 'url|size|mime|extmetadata', 'iiurlwidth': '1920', 'titles': '|'.join(batch)})
        for page in payload.get('query', {}).get('pages', []):
            infos = page.get('imageinfo') or []
            if not infos:
                continue
            info = infos[0]
            ext = info.get('extmetadata') or {}
            meta = {
                'width': int(info.get('width') or 0), 'height': int(info.get('height') or 0),
                'mime': info.get('mime') or '', 'url': info.get('thumburl') or info.get('url') or '',
                'original_url': info.get('url') or '', 'source': info.get('descriptionurl') or '',
                'license': strip_html((ext.get('LicenseShortName') or {}).get('value', '')),
                'artist': strip_html((ext.get('Artist') or {}).get('value', '')),
                'credit': strip_html((ext.get('Credit') or {}).get('value', '')),
            }
            for qid in title_map.get(page.get('title', ''), []):
                candidates[qid]['commons'] = meta
        time.sleep(.15)


def license_ok(value: str) -> bool:
    v = value.lower().replace('_', ' ')
    return any(x in v for x in FREE_LICENSE)


def image_ok(meta: dict, long_edge: int, short_edge: int) -> bool:
    w, h = int(meta.get('width') or 0), int(meta.get('height') or 0)
    return max(w, h) >= long_edge and min(w, h) >= short_edge


def duplicate(item: dict, accepted: list[dict], existing: list[dict]) -> bool:
    nk, ck = norm(item['name']), norm(item['city'])
    for other in [*existing, *accepted]:
        if nk == other.get('name_key') and (not ck or not other.get('city_key') or ck == other.get('city_key')):
            return True
        if distance_m(item, other) < 18:
            ok = other.get('name_key', '')
            if nk == ok or nk in ok or ok in nk:
                return True
    return False


def select(candidates: dict[str, dict], existing: list[dict], target: int, long_edge: int, short_edge: int) -> tuple[list[dict], dict]:
    need = max(0, target-len(existing))
    accepted, stats = [], {'needed': need, 'no_commons': 0, 'bad_license': 0, 'low_res': 0, 'duplicate': 0}
    for item in sorted(candidates.values(), key=lambda x: (x['category'], x['city'], x['name'], x['qid'])):
        meta = item.get('commons')
        if not meta or not meta.get('url'):
            stats['no_commons'] += 1; continue
        if not license_ok(meta.get('license', '')):
            stats['bad_license'] += 1; continue
        if not image_ok(meta, long_edge, short_edge):
            stats['low_res'] += 1; continue
        if duplicate(item, accepted, existing):
            stats['duplicate'] += 1; continue
        item = dict(item); item['name_key'] = norm(item['name']); item['city_key'] = norm(item['city'])
        accepted.append(item)
        if len(accepted) >= need:
            break
    stats['accepted'] = len(accepted)
    return accepted, stats


def spot_id(item: dict) -> str:
    return f"wd-{item['qid'].lower()}-{norm(item['name'])[:48]}".rstrip('-')


def defaults(category: str) -> tuple[str, str, str, str]:
    if category in {'Şelale','Kanyon','Göl','Sahil','Dağ','Park','Mağara'}:
        return ('Sabah erken veya gün batımı', 'Güvenli ziyaret alanından ana doğal oluşumu ve çevre peyzajını birlikte değerlendir', '16-35mm', 'Orta' if category in {'Kanyon','Dağ','Mağara'} else 'Kolay')
    if category in {'Müze','Cami','Manastır'}:
        return ('Ziyaret saatleri', 'Yapının ana cephesini ve mimari detaylarını ziyaret rotasında değerlendir', '24-70mm', 'Kolay')
    return ('Sabah veya akşamüstü', 'Ana ziyaret yapısını çevresi ve yaklaşım aksıyla birlikte değerlendir', '24-70mm', 'Kolay')


def write_files(items: list[dict]) -> None:
    p = ["import '../models/photo_spot.dart';", '', '/// Direct P625 + P18 + Commons quality gate generated catalog.', 'const verifiedTravelPlacesGenerated = <PhotoSpot>[']
    e = ["import 'spot_coordinate_verification_registry.dart';", '', 'const verifiedSpotCoordinateEvidenceGenerated = <String, SpotCoordinateVerificationEvidence>{']
    im = ["import 'spot_image_registry.dart';", '', 'const verifiedTravelImageRegistryGenerated = <String, SpotImageInfo>{']
    quality = {}
    for item in items:
        sid = spot_id(item); bt, angle, lens, diff = defaults(item['category']); meta = item['commons']
        district = item.get('district', '').strip()
        tags = ['Gezilecek Yer','Doğrulanmış','KaynakDoğrulanmış',item['city']]
        if district:
            tags.append(district)
        tags += [item['category'],'Wikidata']
        admin_text = (
            f"{district} ilçesi, {item['city']}"
            if district
            else item['city']
        )
        desc = f"{item['name']}, {admin_text} konumu ve temsil fotoğrafı doğrudan Wikidata ile doğrulanmış Türkiye gezi ve fotoğraf noktasıdır."
        p += ['  PhotoSpot(', f"    id: '{ds(sid)}',", f"    name: '{ds(item['name'])}',", f"    city: '{ds(item['city'])}',", f"    latitude: {item['lat']:.6f},", f"    longitude: {item['lng']:.6f},", '    rating: 4.8,', f"    bestTime: '{ds(bt)}',", f"    angle: '{ds(angle)}',", "    imageUrl: '',", f"    category: '{ds(item['category'])}',", f"    description: '{ds(desc)}',", f"    recommendedLens: '{lens}',", f"    difficulty: '{diff}',", '    tags: [' + ', '.join(f"'{ds(t)}'" for t in tags) + '],', '  ),']
        admin_ref = (
            f" / province={item.get('province_qid', '')}:{item['city']}"
            f" / district={item.get('district_qid', '')}:{district}"
            if district
            else ''
        )
        e += [f"  '{ds(sid)}': SpotCoordinateVerificationEvidence(", "    sourceName: 'Wikidata P625 + P131',", f"    sourceRef: '{item['qid']} / {item['lat']:.6f},{item['lng']:.6f}{ds(admin_ref)}',", "    verifiedAt: 'generated',", '  ),']
        author = meta.get('artist') or meta.get('credit') or 'Wikimedia Commons contributor'
        im += [f"  '{ds(sid)}': SpotImageInfo(", f"    networkUrl: '{ds(meta['url'])}',", "    sourceName: 'Wikimedia Commons (Wikidata P18)',", f"    author: '{ds(author)}',", f"    license: '{ds(meta['license'])}',", f"    sourcePage: '{ds(meta['source'])}',", '  ),']
        quality[sid] = {'wikidataQid': item['qid'], 'province': item['city'], 'provinceQid': item.get('province_qid', ''), 'district': district, 'districtQid': item.get('district_qid', ''), 'width': meta['width'], 'height': meta['height'], 'mime': meta['mime'], 'license': meta['license'], 'sourcePage': meta['source'], 'originalUrl': meta['original_url'], 'displayUrl': meta['url']}
    p.append('];'); e += ['};', '', 'bool isSpotCoordinateIndependentlyVerifiedGenerated(String spotId) =>', '    verifiedSpotCoordinateEvidenceGenerated.containsKey(spotId);']; im.append('};')
    PLACES.write_text('\n'.join(p)+'\n', encoding='utf-8'); EVIDENCE.write_text('\n'.join(e)+'\n', encoding='utf-8'); IMAGES.write_text('\n'.join(im)+'\n', encoding='utf-8'); QUALITY.write_text(json.dumps(quality, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def main() -> int:
    ap = argparse.ArgumentParser(); ap.add_argument('--target-total', type=int, default=1100); ap.add_argument('--page-size', type=int, default=250); ap.add_argument('--per-source-limit', type=int, default=4000); ap.add_argument('--min-long-edge', type=int, default=1600); ap.add_argument('--min-short-edge', type=int, default=900); ap.add_argument('--allow-shortfall', action='store_true'); args = ap.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    existing = existing_places(); print(f'existing verified: {len(existing)}')
    candidates = wikidata_candidates(args.page_size, args.per_source_limit); print(f'unique candidates: {len(candidates)}')
    commons_meta(candidates)
    accepted, stats = select(candidates, existing, args.target_total, args.min_long_edge, args.min_short_edge)
    write_files(accepted)
    report = {'existing_verified': len(existing), 'generated': len(accepted), 'result_total': len(existing)+len(accepted), 'target_total': args.target_total, 'min_long_edge': args.min_long_edge, 'min_short_edge': args.min_short_edge, 'selection': stats}
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8'); print(json.dumps(report, ensure_ascii=False, indent=2))
    if report['result_total'] < args.target_total and not args.allow_shortfall:
        print('Target not reached; catalog was not silently padded with weak data.', file=sys.stderr); return 2
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
