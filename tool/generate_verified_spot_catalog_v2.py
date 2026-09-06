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
PRIORITY_PROVINCES = (
    'elazig',
    'malatya',
    'diyarbakir',
    'tunceli',
    'bingol',
)

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


def province_query_body(class_clause: str, limit: int, offset: int) -> str:
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image
      ?admin ?adminLabel ?district ?districtLabel WHERE {{
  ?item wdt:P17 wd:Q43 ; wdt:P625 ?coord ; wdt:P18 ?image {class_clause} .
  ?item wdt:P131* ?district .
  ?district wdt:P31 wd:{DISTRICT_CLASS} ;
            wdt:P131* ?admin .
  ?admin wdt:P31 wd:{PROVINCE_CLASS} .
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?item ?admin ?district LIMIT {limit} OFFSET {offset}'''


def province_root_query(root: str, limit: int, offset: int) -> str:
    return province_query_body(
        f'; wdt:P31 ?class . ?class wdt:P279* wd:{root}',
        limit,
        offset,
    )


def province_heritage_query(limit: int, offset: int) -> str:
    return province_query_body('; wdt:P1435 ?heritage', limit, offset)


def usable_label(value: str, qid: str) -> bool:
    value = value.strip()
    return bool(value) and base.norm(value) != base.norm(qid)


def district_collect_query(
    query_builder,
    category: str,
    page_size: int,
    max_rows: int,
    out: dict[str, dict],
) -> None:
    """Collect only province+district-resolved rows and flag ambiguity."""
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
            province_qid = row.get('admin', {}).get('value', '').rsplit('/', 1)[-1]
            district_qid = row.get('district', {}).get('value', '').rsplit('/', 1)[-1]
            point = base.point(row.get('coord', {}).get('value', ''))
            name = row.get('itemLabel', {}).get('value', '').strip()
            image = row.get('image', {}).get('value', '').strip()
            city = row.get('adminLabel', {}).get('value', '').strip()
            district = row.get('districtLabel', {}).get('value', '').strip()
            if not (
                qid.startswith('Q')
                and province_qid.startswith('Q')
                and district_qid.startswith('Q')
                and point
                and image
                and usable_label(name, qid)
                and usable_label(city, province_qid)
                and usable_label(district, district_qid)
            ):
                continue
            resolved = {
                'qid': qid,
                'name': name,
                'city': city,
                'district': district,
                'province_qid': province_qid,
                'district_qid': district_qid,
                'lat': point[0],
                'lng': point[1],
                'image': image,
                'category': category,
            }
            previous = out.get(qid)
            if previous is None:
                out[qid] = resolved
            elif (
                previous.get('province_qid') != province_qid
                or previous.get('district_qid') != district_qid
            ):
                previous['ambiguous_admin'] = True
        offset += len(rows)
        if len(rows) < limit:
            break
        base.time.sleep(.35)


def province_key(value: str) -> str:
    key = base.norm(value)
    for suffix in ('-province', '-ili', '-il'):
        if key.endswith(suffix):
            key = key[:-len(suffix)]
    return key


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
base.collect_query = district_collect_query
base.duplicate = strict_duplicate
base.select = priority_select
base.ROOT_CLASSES.update(EXPANSION_ROOT_CLASSES)

if __name__ == '__main__':
    raise SystemExit(base.main())
