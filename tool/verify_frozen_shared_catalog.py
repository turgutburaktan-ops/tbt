#!/usr/bin/env python3
"""Revalidate only frozen records; never discover candidates or download images.

Outputs a review manifest, never writes Firebase. Network failures fail closed.
Existing catalog files remain untouched. Cache files contain public source data.
"""
import concurrent.futures
import hashlib
import html
import json
import math
import re
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import audit_verified_spot_catalog_v2 as audit_v2
import generate_verified_spot_catalog_v2 as geo

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/frozen_shared_catalog'
CACHE = OUT / 'source_cache'
UA = 'TBT-Frozen-Catalog-Audit/1.0 (https://trtbt.com)'


def fetch(url, params):
    target = url + '?' + urllib.parse.urlencode(params)
    path = CACHE / (hashlib.sha256(target.encode()).hexdigest() + '.json')
    if path.exists() and time.time() - path.stat().st_mtime < 86400:
        try:
            return json.loads(path.read_text())
        except json.JSONDecodeError:
            pass
    error = None
    for _ in range(2):
        try:
            if url == 'https://commons.wikimedia.org/w/api.php':
                # Read-only action=query via POST avoids long encoded file URLs.
                req = urllib.request.Request(url, data=urllib.parse.urlencode(params).encode(),
                    headers={'User-Agent': UA, 'Content-Type': 'application/x-www-form-urlencoded'})
            else:
                req = urllib.request.Request(target, headers={'User-Agent': UA})
            with urllib.request.urlopen(req, timeout=25) as response:
                data = json.load(response)
            if 'error' in data:
                raise ValueError(str(data['error'].get('code', 'source_error')))
            temporary = path.with_suffix('.tmp')
            temporary.write_text(json.dumps(data, ensure_ascii=False))
            temporary.replace(path)
            return data
        except Exception as exc:
            error = exc
    raise RuntimeError(f'Source request failed: {url}: {type(error).__name__}')


def batches(values, size):
    return [values[i:i+size] for i in range(0, len(values), size)]


def claims(entity, prop):
    rows = [c for c in entity.get('claims', {}).get(prop, []) if c.get('rank') != 'deprecated']
    preferred = [c for c in rows if c.get('rank') == 'preferred']
    return [c.get('mainsnak', {}).get('datavalue', {}).get('value') for c in preferred or rows]


def entity_batch(ids):
    return fetch(geo.WIKIDATA_API, {'action': 'wbgetentities', 'format': 'json',
        'ids': '|'.join(ids), 'props': 'claims|labels', 'languages': 'tr|en'}).get('entities', {})


def entity_graph(qids):
    entities, frontier = {}, set(qids)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for depth in range(10):
            missing = sorted(frontier - entities.keys())
            if not missing:
                break
            tasks = batches(missing, 40)
            for index, result in enumerate(pool.map(entity_batch, tasks)):
                entities.update(result)
                if index % 10 == 0:
                    print(f'Wikidata depth={depth} batches={index+1}/{len(tasks)}', flush=True)
            frontier = set()
            for qid in missing:
                for prop in ('P131',):
                    frontier.update(geo.ranked_claim_qids(entities.get(qid, {}), prop))
        # Class evidence follows P279 only, never a general Wikidata graph crawl.
        frontier = {qid for entity in entities.values() for qid in geo.ranked_claim_qids(entity, 'P31')}
        for depth in range(9):
            missing = sorted(frontier - entities.keys())
            for result in pool.map(entity_batch, batches(missing, 40)):
                entities.update(result)
            next_frontier = {parent for qid in frontier for parent in geo.ranked_claim_qids(entities.get(qid, {}), 'P279')}
            if not next_frontier:
                break
            frontier = next_frontier
    return entities


def title(value):
    return urllib.parse.unquote(value.rsplit('/', 1)[-1]).replace('_', ' ').removeprefix('File:')


def clean(value):
    return html.unescape(re.sub('<[^>]*>', '', value or '')).strip()


def commons_batch(names):
    data = fetch('https://commons.wikimedia.org/w/api.php', {'action': 'query',
        'format': 'json', 'formatversion': '2', 'prop': 'imageinfo',
        'iiprop': 'url|size|mime|extmetadata', 'iiurlwidth': '500',
        'titles': '|'.join('File:' + n for n in names)})
    return commons_pages(data)


def commons_pages(data):
    pages = {p['title'].removeprefix('File:'): p for p in data.get('query', {}).get('pages', [])}
    for item in data.get('query', {}).get('normalized', []):
        source, dest = item['from'].removeprefix('File:'), item['to'].removeprefix('File:')
        if dest in pages:
            pages[source] = pages[dest]
    return pages


def distance(a, b):
    lat, lng, lat2, lng2 = map(math.radians, (a['lat'], a['lng'], b['lat'], b['lng']))
    h = math.sin((lat2-lat)/2)**2 + math.cos(lat)*math.cos(lat2)*math.sin((lng2-lng)/2)**2
    return 12742000 * math.asin(math.sqrt(min(1, max(0, h))))


def free_license(ext):
    short = clean(ext.get('LicenseShortName', {}).get('value', ''))
    url = ext.get('LicenseUrl', {}).get('value', '')
    valid = bool(re.fullmatch(r'CC BY(?:-SA)? [1-4]\.0', short)) and bool(re.match(
        r'https?://creativecommons\.org/licenses/by(?:-sa)?/[1-4]\.0(?:/|$)', url))
    valid |= short in ('CC0', 'Public domain') and (
        'creativecommons.org/publicdomain/' in url or ext.get('Copyrighted', {}).get('value') == 'False')
    return valid, short, url


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    base = audit_v2.base
    rows = base.places()
    quality = json.loads(base.QUALITY.read_text())
    categories = {}
    for path in base.DATA.glob('verified_travel_places*.dart'):
        for body in base.PHOTO_RE.findall(path.read_text()):
            categories[base.sf(body, 'id')] = base.sf(body, 'category') or 'Genel'
    entities = entity_graph({q[k] for q in quality.values() for k in ('wikidataQid', 'provinceQid', 'districtQid')})
    names = sorted({title(q['sourcePage']) for q in quality.values()})
    pages = {}
    for cached in CACHE.glob('*.json'):
        if time.time() - cached.stat().st_mtime < 86400:
            try:
                pages.update(commons_pages(json.loads(cached.read_text())))
            except json.JSONDecodeError:
                pass
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        tasks = batches([name for name in names if name not in pages], 50)
        for index, result in enumerate(pool.map(commons_batch, tasks)):
            pages.update(result)
            if index % 10 == 0:
                print(f'Commons batches={index+1}/{len(tasks)}', flush=True)
    boundary_cache = OUT / 'boundaries.json'
    if boundary_cache.exists():
        boundaries = json.loads(boundary_cache.read_text())
    else:
        boundaries = geo.load_hdx_district_boundaries()
        boundary_cache.write_text(json.dumps(boundaries))
    identities = geo.admin_identity_index(entities)
    accepted, rejected, seen_names, seen_ids = [], [], set(), set()
    checked_at = datetime.now(timezone.utc).isoformat()
    for row in sorted(rows, key=lambda r: r['id']):
        sid, reasons = row['id'], []
        q = quality.get(sid)
        if not q:
            rejected.append({'id': sid, 'name': row['name'], 'reasons': ['legacy_missing_structured_district_and_original_image_proof']})
            continue
        entity = entities.get(q['wikidataQid'], {})
        coords = [v for v in claims(entity, 'P625') if isinstance(v, dict) and v.get('globe', '').endswith('/Q2')]
        if not any(distance(row, {'lat': c['latitude'], 'lng': c['longitude']}) <= 2 for c in coords):
            reasons.append('P625_coordinate_mismatch')
        expected = (q['provinceQid'], q['districtQid'])
        ancestry = geo.admin_pairs(q['wikidataQid'], entities)
        boundary = geo.boundary_admin_pair(row, boundaries, identities)
        if sid == 'wd-q6025389-pertek-kalesi':
            # Independently documented correction committed with official URLs.
            if expected != ('Q620742', 'Q2540906') or row['city'] != 'Tunceli':
                reasons.append('official_pertek_correction_missing')
        elif not boundary or tuple(boundary[:2]) != expected or (ancestry and ancestry != {expected}):
            reasons.append('district_boundary_or_Wikidata_conflict')
        if sid in ('wd-q2380189-hazar-golu', 'wd-q34894335-keban-baraj-golu'):
            reasons.append('manual_geography_review_required')
        if sid == 'wd-q6037253-alacali-cami' and title(q['sourcePage']) == 'Festung Harput.jpg':
            # Commons explicitly identifies this image as Harput Castle. A P18
            # statement can itself be wrong; it is not proof of visual identity.
            reasons.append('P18_photo_depicts_Harput_Castle_not_Alacali_Mosque')
        if base.norm(row['city']) != base.norm(q['province']):
            reasons.append('province_label_mismatch')
        name = title(q['sourcePage'])
        if name not in [v.replace('_', ' ') for v in claims(entity, 'P18') if isinstance(v, str)]:
            reasons.append('not_current_direct_P18')
        infos = pages.get(name, {}).get('imageinfo') or []
        info = infos[0] if infos else {}
        ext = info.get('extmetadata', {})
        license_valid, license_name, license_url = free_license(ext)
        if not license_valid:
            reasons.append('free_license_not_proven')
        width, height = info.get('width', 0), info.get('height', 0)
        if max(width, height) < 1600 or min(width, height) < 900 or info.get('mime') not in ('image/jpeg', 'image/png', 'image/webp'):
            reasons.append('source_resolution_or_format')
        artist = clean(ext.get('Artist', {}).get('value', ''))
        if not artist:
            reasons.append('missing_attribution')
        preview = info.get('thumburl', '')
        if not preview.startswith('https://') or info.get('thumbwidth', 10000) > 500:
            reasons.append('small_remote_preview_unavailable')
        key = base.norm(row['name'])
        if not key or sid in seen_ids or key in seen_names:
            reasons.append('duplicate_id_or_global_name')
        if any(distance(row, other) <= 18 for other in accepted):
            reasons.append('duplicate_within_18m')
        if reasons:
            rejected.append({'id': sid, 'name': row['name'], 'reasons': reasons})
            continue
        seen_names.add(key)
        seen_ids.add(sid)
        accepted.append({**row, 'district': q['district'], 'provinceQid': q['provinceQid'],
            'category': categories.get(sid, 'Genel'),
            'districtQid': q['districtQid'], 'wikidataQid': q['wikidataQid'],
            'imageUrl': preview, 'imageOriginalUrl': info['url'], 'imageSourcePage': info['descriptionurl'],
            'imageAuthor': artist, 'imageLicense': license_name, 'imageLicenseUrl': license_url,
            'imageWidth': width, 'imageHeight': height, 'checkedAt': checked_at})
    report = {'checkedAt': checked_at, 'frozenTotal': len(rows), 'acceptedCount': len(accepted),
        'heldCount': len(rejected), 'holdReasons': dict(Counter(r for x in rejected for r in x['reasons'])),
        'byProvince': dict(Counter(x['city'] for x in accepted)), 'accepted': accepted, 'held': rejected}
    (OUT / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps({k: v for k, v in report.items() if k not in ('accepted', 'held', 'byProvince')}, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
