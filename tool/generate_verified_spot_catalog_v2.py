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

import io
import json
import urllib.request
import zipfile

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

# Wikidata commonly links a place to the district-seat/town item rather than
# to the newer dedicated district item. Both are explicit Wikidata
# administrative entities; the dedicated district QID remains the evidence
# written to the generated catalog.
# A bounding box is used only for discovery. Publication still requires the
# coordinate to fall inside exactly one official HDX/OCHA ADM2 polygon and
# that district name to map to exactly one Wikidata administrative identity.
ELAZIG_DISCOVERY_BOX = ((37.75, 38.00), (39.55, 40.45))

ELAZIG_DISTRICT_ADMIN_QIDS = {
    'Merkez': ('Q2963425', 'Q174060'),
    'Ağın': ('Q49101030', 'Q794737'),
    'Alacakaya': ('Q115978659', 'Q1019868'),
    'Arıcak': ('Q116006581', 'Q719227'),
    'Baskil': ('Q810374',),
    'Karakoçan': ('Q1868543', 'Q990305'),
    'Keban': ('Q115978913', 'Q1023265'),
    'Kovancılar': ('Q116044805', 'Q1003954'),
    'Maden': ('Q1023303',),
    'Palu': ('Q2341599', 'Q1003910'),
    'Sivrice': ('Q115978893', 'Q928543'),
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
    'Q177380': 'Kaplıca / Sıcak Su Kaynağı',
    'Q631305': 'Kaya Oluşumu',
    'Q82117': 'Tarihi Kent Kapısı',
    'Q24398318': 'İnanç Yapısı',
    'Q35112127': 'Tarihi Yapı',
    'Q1081138': 'Tarihi Alan',
    'Q16748868': 'Tarihi Kent Surları',
}


def candidate_query_body(class_clause: str, limit: int, offset: int) -> str:
    """Discover direct P625/P18 rows; official ADM2 gates prove Turkey later.\n\n    P17 is intentionally not a discovery prerequisite because many otherwise\n    valid Wikidata place items omit it. Publication still requires one Turkish\n    district/province identity or one unambiguous HDX/OCHA ADM2 polygon plus\n    its unique Wikidata administrative identity.\n    """
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image WHERE {{
  ?item wdt:P625 ?coord ; wdt:P18 ?image {class_clause} .
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


def elazig_district_query(
    admin_qids: tuple[str, ...],
    limit: int,
    offset: int,
    *,
    roots: tuple[str, ...] = (),
    heritage: bool = False,
) -> str:
    """Build one deliberately small district query to avoid WDQS timeouts."""
    admins = ' '.join(f'wd:{qid}' for qid in admin_qids)
    if heritage:
        class_clause = '?item wdt:P1435 ?heritage .'
    else:
        root_values = ' '.join(f'wd:{qid}' for qid in roots)
        class_clause = f'''?item wdt:P31 ?class .
  VALUES ?root {{ {root_values} }}
  ?class wdt:P279* ?root .'''
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image WHERE {{
  VALUES ?districtAdmin {{ {admins} }}
  ?item wdt:P17 wd:Q43 ; wdt:P625 ?coord ; wdt:P18 ?image ;
        wdt:P131+ ?districtAdmin .
  {class_clause}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?item LIMIT {limit} OFFSET {offset}'''


def elazig_region_query(
    *,
    roots: tuple[str, ...] = (),
    heritage: bool = False,
    limit: int,
    offset: int,
) -> str:
    """Discover Elazığ-area items even when their P131 claim is incomplete."""
    (south, west), (north, east) = ELAZIG_DISCOVERY_BOX
    if heritage:
        class_clause = '?item wdt:P1435 ?heritage .'
    else:
        root_values = ' '.join(f'wd:{qid}' for qid in roots)
        class_clause = f'''?item wdt:P31 ?class .
  VALUES ?root {{ {root_values} }}
  ?class wdt:P279* ?root .'''
    return f'''SELECT DISTINCT ?item ?itemLabel ?coord ?image WHERE {{
  SERVICE wikibase:box {{
    ?item wdt:P625 ?coord .
    bd:serviceParam wikibase:cornerWest "Point({west} {south})"^^geo:wktLiteral ;
                    wikibase:cornerEast "Point({east} {north})"^^geo:wktLiteral .
  }}
  ?item wdt:P18 ?image .
  {class_clause}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?item LIMIT {limit} OFFSET {offset}'''


def usable_label(value: str, qid: str) -> bool:
    value = value.strip()
    return bool(value) and base.norm(value) != base.norm(qid)


def remember_p18(item: dict, image: str) -> None:
    """Keep every direct P18 option so a weak first statement cannot hide a valid one."""
    images = item.setdefault('p18_images', [])
    primary = item.get('image', '')
    for value in (primary, image):
        if value and value not in images:
            images.append(value)


def best_p18_commons_meta(candidates: dict[str, dict]) -> None:
    """Select the largest freely licensed Commons file among direct P18 values."""
    title_map: dict[str, list[str]] = {}
    for qid, item in candidates.items():
        images = item.get('p18_images') or [item.get('image', '')]
        for image in images:
            if image:
                title = 'File:' + base.filename(image)
                if qid not in title_map.setdefault(title, []):
                    title_map[title].append(qid)
    titles = sorted(title_map)
    for index in range(0, len(titles), 40):
        batch = titles[index:index + 40]
        payload = base.get_json(base.COMMONS, {
            'action': 'query',
            'format': 'json',
            'formatversion': '2',
            'prop': 'imageinfo',
            'iiprop': 'url|size|mime|extmetadata',
            'iiurlwidth': '1920',
            'titles': '|'.join(batch),
        })
        for page in payload.get('query', {}).get('pages', []):
            infos = page.get('imageinfo') or []
            if not infos:
                continue
            info = infos[0]
            ext = info.get('extmetadata') or {}
            meta = {
                'width': int(info.get('width') or 0),
                'height': int(info.get('height') or 0),
                'mime': info.get('mime') or '',
                'url': info.get('thumburl') or info.get('url') or '',
                'original_url': info.get('url') or '',
                'source': info.get('descriptionurl') or '',
                'license': base.strip_html(
                    (ext.get('LicenseShortName') or {}).get('value', '')
                ),
                'artist': base.strip_html(
                    (ext.get('Artist') or {}).get('value', '')
                ),
                'credit': base.strip_html(
                    (ext.get('Credit') or {}).get('value', '')
                ),
            }
            for qid in title_map.get(page.get('title', ''), []):
                candidates[qid].setdefault('commons_options', []).append(meta)
        base.time.sleep(.15)
    for item in candidates.values():
        options = item.pop('commons_options', [])
        if not options:
            continue
        item['commons'] = max(
            options,
            key=lambda meta: (
                base.license_ok(meta.get('license', '')),
                min(meta.get('width', 0), meta.get('height', 0)),
                max(meta.get('width', 0), meta.get('height', 0)),
                meta.get('width', 0) * meta.get('height', 0),
            ),
        )


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
            remember_p18(out[qid], image)
        offset += len(rows)
        if len(rows) < limit:
            break
        base.time.sleep(.35)


def collect_elazig_district_candidates(
    district: str,
    district_qid: str,
    admin_qids: tuple[str, ...],
    page_size: int,
    max_rows: int,
    out: dict[str, dict],
) -> tuple[int, int]:
    """Collect candidates via small queries and preserve P131+ evidence."""
    matched_qids: set[str] = set()
    added = 0
    root_qids = tuple(base.ROOT_CLASSES)
    query_specs = [('heritage', ())]
    query_specs.extend(
        ('classes', root_qids[index:index + 5])
        for index in range(0, len(root_qids), 5)
    )
    for query_kind, roots in query_specs:
        offset = 0
        while offset < max_rows:
            limit = min(page_size, max_rows - offset)
            try:
                payload = base.get_json(
                    base.WDQS,
                    {
                        'query': elazig_district_query(
                            admin_qids,
                            limit,
                            offset,
                            roots=roots,
                            heritage=query_kind == 'heritage',
                        ),
                        'format': 'json',
                    },
                )
            except RuntimeError as error:
                print(
                    f'warning: Elazığ/{district} {query_kind} query skipped '
                    f'after retries: {error}'
                )
                break
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
                matched_qids.add(qid)
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
                        'category': f'Elazığ / {district}',
                    }
                    added += 1
                remember_p18(out[qid], image)
                item = out[qid]
                hint = item.get('elazig_district_hint')
                hint_qid = item.get('elazig_district_qid_hint')
                if hint and (hint != district or hint_qid != district_qid):
                    item['ambiguous_district_hint'] = True
                else:
                    item['elazig_district_hint'] = district
                    item['elazig_district_qid_hint'] = district_qid
            offset += len(rows)
            if len(rows) < limit:
                break
            base.time.sleep(.35)
    return len(matched_qids), added


def collect_elazig_region_candidates(
    page_size: int,
    max_rows: int,
    out: dict[str, dict],
) -> int:
    """Add coordinate-discovered candidates; official polygons decide district."""
    before = len(out)
    root_qids = tuple(base.ROOT_CLASSES)
    query_specs = [('heritage', ())]
    query_specs.extend(
        ('classes', root_qids[index:index + 8])
        for index in range(0, len(root_qids), 8)
    )
    for query_kind, roots in query_specs:
        try:
            candidate_collect_query(
                lambda limit, offset, kind=query_kind, group=roots:
                    elazig_region_query(
                        roots=group,
                        heritage=kind == 'heritage',
                        limit=limit,
                        offset=offset,
                    ),
                'Elazığ boundary discovery',
                page_size,
                max_rows,
                out,
            )
        except RuntimeError as error:
            print(
                f'warning: Elazığ boundary discovery {query_kind} skipped '
                f'after retries: {error}'
            )
    added = len(out) - before
    print(f'Elazığ boundary-discovery additions: {added}')
    return added


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
            entity = entities.get(qid, {})
            next_frontier.update(ranked_claim_qids(entity, 'P131'))
            # Fetch instance/subclass entities too. Turkish districts and
            # provinces are not always typed with the root class directly.
            next_frontier.update(ranked_claim_qids(entity, 'P31'))
            next_frontier.update(ranked_claim_qids(entity, 'P279'))
        frontier = next_frontier
        if not frontier:
            break
    return entities


def class_descends_from(
    qid: str,
    target: str,
    entities: dict[str, dict],
    max_depth: int = 8,
) -> bool:
    """Accept explicit class ancestry only; never infer from a label."""
    queue = [(qid, 0)]
    seen: set[str] = set()
    while queue:
        current, depth = queue.pop(0)
        if current == target:
            return True
        if current in seen or depth >= max_depth:
            continue
        seen.add(current)
        for parent in ranked_claim_qids(entities.get(current, {}), 'P279'):
            queue.append((parent, depth + 1))
    return False


def entity_is_admin_class(
    entity: dict,
    target: str,
    entities: dict[str, dict],
) -> bool:
    return any(
        class_descends_from(class_qid, target, entities)
        for class_qid in ranked_claim_qids(entity, 'P31')
    )


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
        if entity_is_admin_class(entity, DISTRICT_CLASS, entities):
            district = current
        if entity_is_admin_class(entity, PROVINCE_CLASS, entities) and district:
            pairs.add((current, district))
            continue
        for parent in ranked_claim_qids(entity, 'P131'):
            queue.append((parent, district, depth + 1))
    return pairs


HDX_PACKAGE_API = 'https://data.humdata.org/api/3/action/package_show'


def boundary_key(value: str) -> str:
    key = base.norm(value)
    for suffix in ('-province', '-ili', '-il', '-district', '-ilcesi', '-ilce'):
        if key.endswith(suffix):
            key = key[:-len(suffix)]
    return key


def property_value(properties: dict, candidates: tuple[str, ...]) -> str:
    normalized = {base.norm(str(key)): value for key, value in properties.items()}
    for candidate in candidates:
        value = normalized.get(base.norm(candidate))
        if value is not None and str(value).strip():
            return str(value).strip()
    return ''


def coordinate_bounds(value, bounds=None):
    if bounds is None:
        bounds = [180.0, 90.0, -180.0, -90.0]
    if (
        isinstance(value, (list, tuple))
        and len(value) >= 2
        and isinstance(value[0], (int, float))
        and isinstance(value[1], (int, float))
    ):
        x, y = float(value[0]), float(value[1])
        bounds[0] = min(bounds[0], x)
        bounds[1] = min(bounds[1], y)
        bounds[2] = max(bounds[2], x)
        bounds[3] = max(bounds[3], y)
    elif isinstance(value, (list, tuple)):
        for child in value:
            coordinate_bounds(child, bounds)
    return tuple(bounds)


def point_in_ring(x: float, y: float, ring: list) -> bool:
    inside = False
    previous = ring[-1]
    for current in ring:
        x1, y1 = float(previous[0]), float(previous[1])
        x2, y2 = float(current[0]), float(current[1])
        if ((y1 > y) != (y2 > y)):
            cross_x = (x2 - x1) * (y - y1) / (y2 - y1) + x1
            if x < cross_x:
                inside = not inside
        previous = current
    return inside


def point_in_geometry(x: float, y: float, geometry: dict) -> bool:
    coordinates = geometry.get('coordinates') or []
    geometry_type = geometry.get('type')
    polygons = [coordinates] if geometry_type == 'Polygon' else coordinates
    if geometry_type not in {'Polygon', 'MultiPolygon'}:
        return False
    for polygon in polygons:
        if not polygon or not point_in_ring(x, y, polygon[0]):
            continue
        if any(point_in_ring(x, y, hole) for hole in polygon[1:]):
            continue
        return True
    return False


def load_hdx_district_boundaries() -> list[dict]:
    """Download COD-AB only for generation; never bundle polygons in the app."""
    package = base.get_json(HDX_PACKAGE_API, {'id': 'cod-ab-tur'})
    resources = package.get('result', {}).get('resources', [])
    geojson_resources = [
        resource for resource in resources
        if 'geojson' in (
            str(resource.get('format', '')) + ' ' + str(resource.get('name', ''))
        ).lower()
    ]
    if not geojson_resources:
        raise RuntimeError('HDX Turkey ADM2 GeoJSON resource was not found')
    resource = next(
        (
            item for item in geojson_resources
            if 'admin_boundaries.geojson.zip' in str(item.get('name', '')).lower()
        ),
        geojson_resources[0],
    )
    request = urllib.request.Request(
        resource['url'],
        headers={'User-Agent': base.UA},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        payload = response.read()
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        members = [
            name for name in archive.namelist()
            if name.lower().endswith(('.geojson', '.json'))
            and ('adm2' in name.lower() or 'admin2' in name.lower())
        ]
        if not members:
            members = [
                name for name in archive.namelist()
                if name.lower().endswith(('.geojson', '.json'))
            ]
        if not members:
            raise RuntimeError('HDX archive contains no GeoJSON')
        data = json.loads(archive.read(members[-1]).decode('utf-8'))
    boundaries = []
    for feature in data.get('features', []):
        properties = feature.get('properties') or {}
        province = property_value(
            properties,
            ('ADM1_TR', 'ADM1_EN', 'adm1_name', 'province', 'il'),
        )
        district = property_value(
            properties,
            ('ADM2_TR', 'ADM2_EN', 'adm2_name', 'district', 'ilce', 'ilçe'),
        )
        geometry = feature.get('geometry') or {}
        if not province or not district or not geometry:
            continue
        boundaries.append({
            'province': province,
            'district': district,
            'geometry': geometry,
            'bounds': coordinate_bounds(geometry.get('coordinates') or []),
        })
    if len(boundaries) < 900:
        raise RuntimeError(
            f'HDX district coverage unexpectedly small: {len(boundaries)}'
        )
    print(f'HDX district boundaries loaded: {len(boundaries)}')
    return boundaries


def admin_identity_index(entities: dict[str, dict]) -> dict[tuple[str, str], set[tuple[str, str, str, str]]]:
    index: dict[tuple[str, str], set[tuple[str, str, str, str]]] = {}
    for qid, entity in entities.items():
        if not entity_is_admin_class(entity, DISTRICT_CLASS, entities):
            continue
        district_label = entity_label(entity, qid)
        for province_qid, district_qid in admin_pairs(qid, entities):
            province_label = entity_label(entities.get(province_qid, {}), province_qid)
            if not province_label or not district_label:
                continue
            key = (boundary_key(province_label), boundary_key(district_label))
            index.setdefault(key, set()).add(
                (province_qid, district_qid, province_label, district_label)
            )
    return index



def fetch_turkey_admin_identity_index() -> dict[tuple[str, str], set[tuple[str, str, str, str]]]:
    """Load every Turkish district/province identity for polygon resolution.

    This does not infer administration from a label: Wikidata must explicitly
    type the two entities as a Turkish district and province and connect the
    district to the province. HDX/OCHA still decides the containing polygon.
    """
    query = f'''SELECT DISTINCT ?province ?provinceLabel ?district ?districtLabel WHERE {{
  ?district wdt:P31/wdt:P279* wd:{DISTRICT_CLASS} ;
            wdt:P131+ ?province .
  ?province wdt:P31/wdt:P279* wd:{PROVINCE_CLASS} .
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "tr,en". }}
}} ORDER BY ?province ?district'''
    payload = base.get_json(base.WDQS, {'query': query, 'format': 'json'})
    index: dict[tuple[str, str], set[tuple[str, str, str, str]]] = {}
    for row in payload.get('results', {}).get('bindings', []):
        province_uri = row.get('province', {}).get('value', '')
        district_uri = row.get('district', {}).get('value', '')
        province_qid = province_uri.rsplit('/', 1)[-1]
        district_qid = district_uri.rsplit('/', 1)[-1]
        province_label = row.get('provinceLabel', {}).get('value', '').strip()
        district_label = row.get('districtLabel', {}).get('value', '').strip()
        if not (
            province_qid.startswith('Q')
            and district_qid.startswith('Q')
            and usable_label(province_label, province_qid)
            and usable_label(district_label, district_qid)
        ):
            continue
        key = (boundary_key(province_label), boundary_key(district_label))
        index.setdefault(key, set()).add(
            (province_qid, district_qid, province_label, district_label)
        )
    print(f'Wikidata Turkish district identities loaded: {len(index)}')
    return index


def boundary_admin_pair(
    item: dict,
    boundaries: list[dict],
    identities: dict[tuple[str, str], set[tuple[str, str, str, str]]],
):
    x, y = item['lng'], item['lat']
    matches = []
    for boundary in boundaries:
        min_x, min_y, max_x, max_y = boundary['bounds']
        if not (min_x <= x <= max_x and min_y <= y <= max_y):
            continue
        if point_in_geometry(x, y, boundary['geometry']):
            matches.append(boundary)
    if len(matches) != 1:
        return None
    boundary = matches[0]
    key = (
        boundary_key(boundary['province']),
        boundary_key(boundary['district']),
    )
    candidates = identities.get(key, set())
    if len(candidates) != 1:
        return None
    return next(iter(candidates))


_base_wikidata_candidates = base.wikidata_candidates


def district_resolved_candidates(page_size: int, per_source_limit: int) -> dict[str, dict]:
    candidates = _base_wikidata_candidates(page_size, per_source_limit)
    district_matches = 0
    district_additions = 0
    for district, district_qid in ELAZIG_DISTRICT_QIDS.items():
        matched, added = collect_elazig_district_candidates(
            district,
            district_qid,
            ELAZIG_DISTRICT_ADMIN_QIDS[district],
            page_size,
            per_source_limit,
            candidates,
        )
        district_matches += matched
        district_additions += added
    print(
        'Elazığ district-priority matches/additions: '
        f'{district_matches}/{district_additions}'
    )
    collect_elazig_region_candidates(page_size, per_source_limit, candidates)
    entities = fetch_admin_entities(candidates)
    try:
        boundaries = load_hdx_district_boundaries()
        identities = admin_identity_index(entities)
        try:
            complete_identities = fetch_turkey_admin_identity_index()
            for key, values in complete_identities.items():
                identities.setdefault(key, set()).update(values)
        except Exception as error:
            print(
                'warning: complete Wikidata district identity lookup unavailable: '
                f'{error}'
            )
    except Exception as error:
        print(f'warning: HDX district boundary fallback unavailable: {error}')
        boundaries = []
        identities = {}
    resolved = 0
    boundary_resolved = 0
    ambiguous = 0
    for qid, item in candidates.items():
        pairs = admin_pairs(qid, entities)
        hint = item.get('elazig_district_hint', '')
        hint_qid = item.get('elazig_district_qid_hint', '')
        if hint and not item.get('ambiguous_district_hint'):
            hinted_pair = ('Q483091', hint_qid)
            if pairs and hinted_pair not in pairs:
                item['ambiguous_admin'] = True
                ambiguous += 1
                continue
            province_qid, district_qid = hinted_pair
            city = 'Elazığ'
            district = hint
        elif len(pairs) == 1:
            province_qid, district_qid = next(iter(pairs))
            city = entity_label(entities.get(province_qid, {}), province_qid)
            district = entity_label(entities.get(district_qid, {}), district_qid)
        else:
            boundary_pair = boundary_admin_pair(item, boundaries, identities)
            if not boundary_pair:
                item['ambiguous_admin'] = True
                ambiguous += 1
                continue
            province_qid, district_qid, city, district = boundary_pair
            item['admin_source'] = 'HDX COD-AB boundary + Wikidata identity'
            boundary_resolved += 1
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
    print(
        f'district resolved: {resolved}; boundary resolved: {boundary_resolved}; '
        f'unresolved/ambiguous: {ambiguous}'
    )
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
base.commons_meta = best_p18_commons_meta
base.wikidata_candidates = district_resolved_candidates
base.duplicate = strict_duplicate
base.select = priority_select
base.ROOT_CLASSES.update(EXPANSION_ROOT_CLASSES)

if __name__ == '__main__':
    raise SystemExit(base.main())
