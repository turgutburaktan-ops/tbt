"""Build province catalog input from the public Geofabrik Turkey OSM extract.

Source: https://download.geofabrik.de/europe/turkey.html
Data: © OpenStreetMap contributors, ODbL. No photographs are imported.
"""
import json
import sys
from collections import Counter
from pathlib import Path
import osmium
from shapely import wkb
from shapely.geometry import Point
from shapely.strtree import STRtree

PROVINCES = json.loads((Path(__file__).parents[1] / 'catalog/provinces.json').read_text())
CATEGORIES = {
    'cafe': {'amenity': {'cafe', 'ice_cream', 'juice_bar'}, 'shop': {'coffee', 'pastry', 'confectionery', 'tea', 'chocolate'}},
    'dining': {'amenity': {'restaurant', 'fast_food', 'food_court', 'bar', 'pub', 'biergarten', 'bbq'}, 'shop': {'bakery', 'deli', 'butcher', 'seafood', 'cheese', 'pasta', 'convenience'}},
    'hotel': {'tourism': {'hotel', 'hostel', 'guest_house', 'motel', 'apartment', 'chalet', 'resort', 'camp_site', 'caravan_site'}},
}

def main(source, target):
    factory = osmium.geom.WKBFactory()
    bounds, candidates = {}, {}
    processor = (osmium.FileProcessor(source).with_locations().with_areas(
        osmium.filter.KeyFilter('amenity', 'shop', 'tourism', 'admin_level'))
        .with_filter(osmium.filter.KeyFilter('amenity', 'shop', 'tourism', 'admin_level')))
    for obj in processor:
        tags = dict(obj.tags)
        if obj.is_area() and tags.get('admin_level') == '4':
            iso = tags.get('ISO3166-2', '')
            if iso.startswith('TR-') and iso[3:].isdigit() and 1 <= int(iso[3:]) <= 81:
                geometry = wkb.loads(factory.create_multipolygon(obj), hex=True)
                if geometry.is_valid and not geometry.is_empty:
                    bounds[PROVINCES[int(iso[3:])-1]] = geometry
        kinds = [k for k, filters in CATEGORIES.items() if any(tags.get(t) in values for t, values in filters.items())]
        if not kinds or not (tags.get('name:tr') or tags.get('name')):
            continue
        if obj.is_node() and obj.location.valid():
            typ, oid, lat, lon = 'node', obj.id, obj.lat, obj.lon
        elif obj.is_way():
            points = [(n.lat, n.lon) for n in obj.nodes if n.location.valid()]
            if len(points) != len(obj.nodes) or not points:
                continue
            typ, oid = 'way', obj.id
            lat = (min(p[0] for p in points) + max(p[0] for p in points)) / 2
            lon = (min(p[1] for p in points) + max(p[1] for p in points)) / 2
        elif obj.is_area() and not obj.from_way():
            geometry = wkb.loads(factory.create_multipolygon(obj), hex=True)
            left, bottom, right, top = geometry.bounds
            typ, oid, lat, lon = 'relation', obj.orig_id(), (bottom+top)/2, (left+right)/2
        else:
            continue
        candidates[(typ, oid)] = (kinds, tags, lat, lon)
    missing = sorted(set(PROVINCES) - set(bounds))
    if missing:
        raise RuntimeError(f'Province boundaries incomplete: {missing}; no import produced')
    cities = list(bounds)
    shapes = [bounds[c] for c in cities]
    tree = STRtree(shapes)
    counts, unassigned = Counter(), 0
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('w') as out:
        for (typ, oid), (kinds, tags, lat, lon) in candidates.items():
            point = Point(lon, lat)
            matches = [int(i) for i in tree.query(point) if shapes[int(i)].covers(point)]
            if len(matches) != 1:
                unassigned += 1
                continue
            city = cities[matches[0]]
            for kind in kinds:
                row = {'city': city, 'kind': kind, 'element': {'type': typ, 'id': oid, 'lat': lat, 'lon': lon, 'tags': tags}}
                out.write(json.dumps(row, ensure_ascii=False) + '\n')
                counts[f'{city}/{kind}'] += 1
    report = {'source': 'Geofabrik Turkey / OpenStreetMap', 'license': 'ODbL', 'provinces': len(bounds),
              'rows': sum(counts.values()), 'unassignedOutsideOrBoundary': unassigned, 'counts': dict(sorted(counts.items()))}
    target.with_suffix('.report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False), flush=True)
    if not counts:
        raise RuntimeError('Empty extract; nothing may be imported')

if __name__ == '__main__':
    main(*sys.argv[1:])
