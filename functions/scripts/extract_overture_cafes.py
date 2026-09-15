"""Stream Overture cafes into a province-validated additive import manifest."""
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path

CAFE_CATEGORIES = {'cafe', 'coffee_shop', 'coffeehouse', 'tea_house', 'tea_room'}

def candidate(feature):
    p = feature.get('properties') or {}
    taxonomy = p.get('taxonomy') or {}
    categories = {p.get('basic_category'), taxonomy.get('primary'),
                  (p.get('categories') or {}).get('primary')}
    categories.update(taxonomy.get('hierarchy') or [])
    if not categories.intersection(CAFE_CATEGORIES):
        return None
    confidence = p.get('confidence')
    if not isinstance(confidence, (float, int)) or not math.isfinite(confidence) or confidence < .85:
        return None
    if p.get('operating_status') in {'permanently_closed', 'temporarily_closed', 'closed'}:
        return None
    name = (p.get('names') or {}).get('primary', '').strip()
    oid = p.get('id') or feature.get('id') or ''
    g = feature.get('geometry') or {}
    coords = g.get('coordinates') or []
    if not name or not re.fullmatch(r'[a-zA-Z0-9-]{8,100}', oid) or g.get('type') != 'Point' or len(coords) != 2:
        return None
    lon, lat = coords
    if not all(isinstance(x, (float, int)) and math.isfinite(x) for x in coords):
        return None
    if not (35.4 <= lat <= 42.3 and 25.4 <= lon <= 45.1):
        return None
    addresses = p.get('addresses') or []
    if addresses and not any(a.get('country') == 'TR' for a in addresses):
        return None
    address = next((a for a in addresses if a.get('country') == 'TR'), {})
    return dict(venueId='overture-'+oid, venueName=name, category='cafe', latitude=lat,
                longitude=lon, address=address.get('freeform', ''), district='',
                phone=next(iter(p.get('phones') or []), ''),
                website=next(iter(p.get('websites') or []), ''),
                status='published', source='overture', sourceUrl='https://explore.overturemaps.org/?gers='+oid,
                sourceConfidence=confidence, sourceRecords=p.get('sources') or [])

def features(path):
    with open(path) as f:
        for line in f:
            line = line.strip().lstrip('\x1e')
            if line:
                yield json.loads(line)

def main(bounds_path, places_path, output):
    from shapely.geometry import shape, Point
    from shapely.ops import unary_union
    from shapely.strtree import STRtree
    provinces = json.loads((Path(__file__).parents[1]/'catalog/provinces.json').read_text())
    parts = {}
    for f in features(bounds_path):
        p = f.get('properties') or {}
        region = p.get('region') or ''
        if p.get('country') != 'TR' or p.get('subtype') != 'region' or not re.fullmatch(r'TR-\d{2}', region):
            continue
        i = int(region[3:])
        if 1 <= i <= 81:
            geom = shape(f['geometry'])
            if geom.is_valid and not geom.is_empty:
                parts.setdefault(provinces[i-1], []).append(geom)
    if len(parts) != 81:
        raise RuntimeError('All 81 province boundaries required; missing '+str(set(provinces)-set(parts)))
    cities = list(parts)
    shapes = [unary_union(parts[c]) for c in cities]
    tree = STRtree(shapes)
    counts, seen = Counter(), set()
    with open(output, 'w') as out:
        for f in features(places_path):
            row = candidate(f)
            if not row or row['venueId'] in seen:
                continue
            point = Point(row['longitude'], row['latitude'])
            matches = [int(i) for i in tree.query(point) if shapes[int(i)].covers(point)]
            if len(matches) != 1:
                continue
            row['city'] = cities[matches[0]]
            seen.add(row['venueId'])
            counts[row['city']] += 1
            out.write(json.dumps(row, ensure_ascii=False)+'\n')
    report = {'source':'Overture Maps', 'boundaryProvinces':81, 'cafes':sum(counts.values()), 'byCity':dict(counts)}
    Path(output+'.report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False))
    if not counts.get('Elazığ'):
        raise RuntimeError('No Elazığ cafes passed validation; do not import')

if __name__ == '__main__':
    main(*sys.argv[1:])
