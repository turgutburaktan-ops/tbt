#!/usr/bin/env python3
"""Strict, province-safe wrapper for the nationwide verified-place generator.

The base generator still owns the photo system: direct Wikidata P625 + P18,
Commons free-license checks and the 1600x900 source-image threshold. This
wrapper adds publication gates needed for safe growth toward 10,000:
  * resolve every generated card to one unambiguous Turkish district
    (Q1147395) and province (Q48336),
  * prioritize Elazığ, Malatya, Diyarbakır, Tunceli and Bingöl,
  * reject every second card within 18 metres, regardless of its label.
"""
from __future__ import annotations

import generate_verified_spot_catalog as base

PROVINCE_CLASS = 'Q48336'
DISTRICT_CLASS = 'Q1147395'
WIKIDATA_API = 'https://www.wikidata.org/w/api.php'
PRIORITY_PROVINCES = (
    'elazig',
    'malatya',
    'diyarbakir',
    'tunceli',
    'bingol',
)

ELAZIG_DISTRICTS = (
    'Merkez',
    'Ağın',
    'Alacakaya',
    'Arıcak',
    'Baskil',
    'Karakoçan',
    'Keban',
    'Kovancılar',
    'Maden',
    'Palu',
    'Sivrice',
)

# Dedicated district entities prevent nationwide WDQS page limits from
# starving Elazığ candidates. The district itself is never admitted: every
# candidate must be located in it via one or more P131 steps and still pass a
# tourism/heritage class, direct P625/P18 and Commons quality gates.
ELAZIG_DISTRICT_QIDS = {
    'Merkez': 'Q2963425',
    'Ağın': 'Q49101030',
    'Alacakaya': 'Q115978659',
    'Arıcak': 'Q116006581',
    'Baskil': 'Q810374',
    'Karakoçan': 'Q1868543',
    'Keban': 'Q115978913',
    'Kovancılar': 'Q116044805',
    'Maden': 'Q1023303',
    'Palu': 'Q2341599',
    'Sivrice': 'Q115978893',
}

# Conservative second pass: only notable, mappable place/structure classes.
# Each candidate still has to pass the same direct P625 + P18, Commons licence,
# source-resolution, province ancestry and 18-metre duplicate gates.
EXPANSION_ROOT_CLASSES = {
    'Q4989906': 'Anıt',
    'Q483453': 'Tarihi Çeşme',
    'Q16970': 'Kilise',
    'Q381885': 'Türbe / Mezar Anıtı',
    'Q12518': 'Kule',
    'Q16560': 'Saray',
    'Q34627': 'Sinagog',
    'Q473972': 'Korunan Alan',
    'Q46169': 'Milli Park',
    'Q179049': 'Doğa Koruma Alanı',
    'Q5003624': 'Anma Noktası',
    'Q57821': 'Tarihi Tahkimat',
    'Q785952': 'Tarihi Hamam',
    'Q39614': 'Tarihi Mezarlık',
    'Q860861': 'Heykel / Kamusal Sanat',
    'Q109607': 'Tarihi Harabe',
    'Q186347': 'Kervansaray',
    'Q24354': 'Tiyatro Yapısı',
    'Q23442': 'Ada',
    'Q1107656': 'Bahçe',
    'Q39715': 'Deniz Feneri',
    'Q474': 'Su Kemeri',
    'Q39816': 'Vadi',
    'Q34763': 'Yarımada',
    'Q38720': 'Yel Değirmeni',
    'Q219760': 'Tarihi Çarşı',
    'Q43501': 'Hayvanat Bahçesi',
    'Q2281788': 'Akvaryum',
    'Q194195': 'Eğlence Parkı',
    'Q1329623': 'Kültür Merkezi',
    'Q23790': 'Doğal Anıt',
    'Q6017969': 'Seyir Noktası',
    'Q2319498': 'Mimari Simge',
    'Q54831': 'Amfitiyatro',
    'Q167346': 'Botanik Bahçesi',
    'Q8072': 'Yanardağ',
    'Q4421': 'Orman',
    'Q954501': 'Doğal Kemer',
}


def candidate_query_body(class_clause: str, limit: int, offset: int) -> str:
    """Keep WDQS discovery cheap; resolve P131 ancestry through the API later."""
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image WHERE {{
  ?item wdt:P17 wd:Q43 ; wdt:P625 ?coord ; wdt:P18 ?image {class_clause} .
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?item LIMIT {limit} OFFSET {offset}'''


def province_root_query(root: str, limit: int, offset: int) -> str:
    return candidate_query_body(
        f'; wdt:P31 ?class . ?class wdt:P279* wd:{root}',
        limit,
        offset,
    )


def province_heritage_query(limit: int, offset: int) -> str:
    return candidate_query_body('; wdt:P1435 ?heritage', limit, offset)


def elazig_district_query(district_qid: str, limit: int, offset: int) -> str:
    roots = ' '.join(f'wd:{qid}' for qid in base.ROOT_CLASSES)
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image WHERE {{
  ?item wdt:P17 wd:Q43 ; wdt:P625 ?coord ; wdt:P18 ?image ;
        wdt:P131+ wd:{district_qid} .
  {{ ?item wdt:P1435 ?heritage . }}
  UNION
  {{
    ?item wdt:P31 ?class .
    VALUES ?root {{ {roots} }}
    ?class wdt:P279* ?root .
  }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?item LIMIT {limit} OFFSET {offset}'''


def usable_label(value: str, qid: str) -> bool:
    value = value.strip()
    return bool(value) and base.norm(value) != base.norm(qid)


def candidate_collect_query(
    query_builder,
    category: str,
    page_size: int,
    max_rows: int,
    out: dict[str, dict],
) -> None:
    """Collect direct P625/P18 rows without an expensive recursive join."""
    offset = 0
    while offset < max_rows:
        limit = min(page_size, max_rows - offset)
        payload = base.get_json(
            base.WDQS,
            {'query': query_builder(limit, offset), 'format': 'json'},
        )
        rows = payload.get('results', {}).get('bindings', [])
        if not rows:
            break
        for row in rows:
            uri = row.get('item', {}).get('value', '')
            qid = uri.rsplit('/', 1)[-1]
            point = base.point(row.get('coord', {}).get('value', ''))
            name = row.get('itemLabel', {}).get('value', '').strip()
            image = row.get('image', {}).get('value', '').strip()
            if not (
                qid.startswith('Q')
                and point
                and image
                and usable_label(name, qid)
            ):
                continue
            if qid not in out:
                out[qid] = {
                    'qid': qid,
                    'name': name,
                    'city': '',
                    'district': '',
                    'province_qid': '',
                    'district_qid': '',
                    'lat': point[0],
                    'lng': point[1],
                    'image': image,
                    'category': category,
                }
        offset += len(rows)
        if len(rows) < limit:
            break
        base.time.sleep(.35)


def ranked_claim_qids(entity: dict, prop: str) -> list[str]:
    claims = [
        claim for claim in entity.get('claims', {}).get(prop, [])
        if claim.get('rank') != 'deprecated'
    ]
    preferred = [claim for claim in claims if claim.get('rank') == 'preferred']
    if preferred:
        claims = preferred
    qids = []
    for claim in claims:
        value = claim.get('mainsnak', {}).get('datavalue', {}).get('value', {})
        qid = value.get('id', '') if isinstance(value, dict) else ''
        if qid.startswith('Q') and qid not in qids:
            qids.append(qid)
    return qids


def entity_label(entity: dict, qid: str) -> str:
    labels = entity.get('labels', {})
    for language in ('tr', 'en'):
        value = labels.get(language, {}).get('value', '').strip()
        if usable_label(value, qid):
            return value
    return ''


def fetch_admin_entities(candidates: dict[str, dict], max_depth: int = 8) -> dict[str, dict]:
    """Fetch P131 ancestry in small API batches to avoid WDQS path timeouts."""
    entities: dict[str, dict] = {}
    frontier = set(candidates)
    for _ in range(max_depth + 1):
        missing = sorted(frontier - entities.keys())
        for index in range(0, len(missing), 50):
            batch = missing[index:index + 50]
            payload = base.get_json(WIKIDATA_API, {
                'action': 'wbgetentities',
                'format': 'json',
                'formatversion': '2',
                'ids': '|'.join(batch),
                'props': 'claims|labels',
                'languages': 'tr|en',
            })
            entities.update(payload.get('entities', {}))
            base.time.sleep(.05)
        next_frontier: set[str] = set()
        for qid in frontier:
            next_frontier.update(ranked_claim_qids(entities.get(qid, {}), 'P131'))
        frontier = next_frontier
        if not frontier:
            break
    return entities


def admin_pairs(qid: str, entities: dict[str, dict]) -> set[tuple[str, str]]:
    """Return connected (province, district) pairs in the item's P131 graph."""
    pairs: set[tuple[str, str]] = set()
    queue: list[tuple[str, str | None, int]] = [(qid, None, 0)]
    visited: set[tuple[str, str | None]] = set()
    while queue:
        current, district, depth = queue.pop(0)
        state = (current, district)
        if state in visited or depth > 8:
            continue
        visited.add(state)
        entity = entities.get(current, {})
        classes = set(ranked_claim_qids(entity, 'P31'))
        if DISTRICT_CLASS in classes:
            district = current
        if PROVINCE_CLASS in classes and district:
            pairs.add((current, district))
            continue
        for parent in ranked_claim_qids(entity, 'P131'):
            queue.append((parent, district, depth + 1))
    return pairs


_base_wikidata_candidates = base.wikidata_candidates


def district_resolved_candidates(page_size: int, per_source_limit: int) -> dict[str, dict]:
    candidates = _base_wikidata_candidates(page_size, per_source_limit)
    nationwide_count = len(candidates)
    for district, district_qid in ELAZIG_DISTRICT_QIDS.items():
        candidate_collect_query(
            lambda limit, offset, qid=district_qid: elazig_district_query(
                qid, limit, offset
            ),
            f'Elazığ / {district}',
            page_size,
            per_source_limit,
            candidates,
        )
    print(
        'Elazığ district-priority unique additions: '
        f'{len(candidates) - nationwide_count}'
    )
    entities = fetch_admin_entities(candidates)
    resolved = 0
    ambiguous = 0
    for qid, item in candidates.items():
        pairs = admin_pairs(qid, entities)
        if len(pairs) != 1:
            item['ambiguous_admin'] = True
            ambiguous += 1
            continue
        province_qid, district_qid = next(iter(pairs))
        city = entity_label(entities.get(province_qid, {}), province_qid)
        district = entity_label(entities.get(district_qid, {}), district_qid)
        if province_key(city) == 'elazig':
            district = canonical_elazig_district(district)
        if not city or not district:
            item['ambiguous_admin'] = True
            ambiguous += 1
            continue
        item.update({
            'city': city,
            'district': district,
            'province_qid': province_qid,
            'district_qid': district_qid,
        })
        resolved += 1
    print(f'district resolved: {resolved}; unresolved/ambiguous: {ambiguous}')
    return candidates


def province_key(value: str) -> str:
    key = base.norm(value)
    for suffix in ('-province', '-ili', '-il'):
        if key.endswith(suffix):
            key = key[:-len(suffix)]
    return key


def canonical_elazig_district(value: str) -> str:
    key = base.norm(value)
    for suffix in ('-district', '-ilcesi', '-ilce'):
        if key.endswith(suffix):
            key = key[:-len(suffix)]
    for prefix in ('elazig-', 'elazig-merkez-'):
        if key.startswith(prefix):
            key = key[len(prefix):]
    if key in {'', 'elazig', 'merkez', 'central'}:
        return 'Merkez'
    for district in ELAZIG_DISTRICTS:
        if key == base.norm(district):
            return district
    return ''


def priority_rank(city: str) -> int:
    key = province_key(city)
    for index, province in enumerate(PRIORITY_PROVINCES):
        if key == province or key.startswith(province + '-'):
            return index
    return len(PRIORITY_PROVINCES)


def strict_duplicate(item: dict, accepted: list[dict], existing: list[dict]) -> bool:
    name_key = base.norm(item['name'])
    city_key = province_key(item['city'])
    for other in [*existing, *accepted]:
        other_name = other.get('name_key', '')
        other_city = province_key(other.get('city', '') or other.get('city_key', ''))
        if name_key == other_name and (
            not city_key or not other_city or city_key == other_city
        ):
            return True
        if base.distance_m(item, other) < 18:
            return True
    return False


def priority_select(
    candidates: dict[str, dict],
    existing: list[dict],
    target: int,
    long_edge: int,
    short_edge: int,
) -> tuple[list[dict], dict]:
    need = max(0, target - len(existing))
    accepted: list[dict] = []
    stats = {
        'needed': need,
        'no_commons': 0,
        'bad_license': 0,
        'low_res': 0,
        'duplicate': 0,
        'ambiguous_admin': 0,
    }
    ordered = sorted(
        candidates.values(),
        key=lambda item: (
            priority_rank(item['city']),
            province_key(item['city']),
            item['category'],
            item['name'],
            item['qid'],
        ),
    )
    for item in ordered:
        if item.get('ambiguous_admin'):
            stats['ambiguous_admin'] += 1
            continue
        meta = item.get('commons')
        if not meta or not meta.get('url'):
            stats['no_commons'] += 1
            continue
        if not base.license_ok(meta.get('license', '')):
            stats['bad_license'] += 1
            continue
        if not base.image_ok(meta, long_edge, short_edge):
            stats['low_res'] += 1
            continue
        if strict_duplicate(item, accepted, existing):
            stats['duplicate'] += 1
            continue
        item = dict(item)
        item['name_key'] = base.norm(item['name'])
        item['city_key'] = province_key(item['city'])
        accepted.append(item)
        if len(accepted) >= need:
            break
    stats['accepted'] = len(accepted)
    stats['priority_provinces'] = list(PRIORITY_PROVINCES)
    stats['accepted_by_province'] = {
        city: sum(1 for item in accepted if item['city'] == city)
        for city in sorted({item['city'] for item in accepted})
    }
    stats['elazig_district_coverage'] = {
        district: sum(
            1 for item in accepted
            if province_key(item['city']) == 'elazig'
            and item['district'] == district
        )
        for district in ELAZIG_DISTRICTS
    }
    stats['accepted_by_priority_district'] = {
        f"{item['city']} / {item['district']}": sum(
            1
            for other in accepted
            if other['city'] == item['city']
            and other['district'] == item['district']
        )
        for item in accepted
        if priority_rank(item['city']) < len(PRIORITY_PROVINCES)
    }
    return accepted, stats


base.query_for_root = province_root_query
base.heritage_query = province_heritage_query
base.collect_query = candidate_collect_query
base.wikidata_candidates = district_resolved_candidates
base.duplicate = strict_duplicate
base.select = priority_select
base.ROOT_CLASSES.update(EXPANSION_ROOT_CLASSES)

if __name__ == '__main__':
    raise SystemExit(base.main())
