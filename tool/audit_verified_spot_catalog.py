#!/usr/bin/env python3
"""Fatal quality gate for the 1000+ verified photo-spot catalog."""
from __future__ import annotations

import json
import os
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'lib/data'
OUT = ROOT / 'build/spot_quality/verified_catalog_audit.json'
QUALITY = DATA / 'verified_travel_image_quality_generated.json'
MIN_SPOTS = int(os.getenv('MIN_VERIFIED_SPOTS', '1000'))
MIN_LONG = int(os.getenv('MIN_IMAGE_LONG_EDGE', '1600'))
MIN_SHORT = int(os.getenv('MIN_IMAGE_SHORT_EDGE', '900'))
MIN_LAT, MAX_LAT = 35.4, 42.3
MIN_LNG, MAX_LNG = 25.4, 45.1
PHOTO_RE = re.compile(r'PhotoSpot\((.*?)\n\s*\),', re.DOTALL)
IMAGE_RE = re.compile(r"^\s*'([^']+)'\s*:\s*SpotImageInfo\((.*?)\n\s*\),", re.MULTILINE | re.DOTALL)
EVIDENCE_RE = re.compile(r"^\s*'([^']+)'\s*:\s*SpotCoordinateVerificationEvidence\(", re.MULTILINE)


def norm(value: str) -> str:
    value = value.replace('İ', 'I').replace('ı', 'i')
    value = unicodedata.normalize('NFKD', value)
    value = ''.join(ch for ch in value if not unicodedata.combining(ch))
    return re.sub(r'[^a-z0-9]+', ' ', value.lower()).strip()


def sf(body: str, name: str) -> str:
    m = re.search(rf"{name}:\s*'([^']*)'", body)
    return m.group(1).strip() if m else ''


def nf(body: str, name: str):
    m = re.search(rf'{name}:\s*(-?\d+(?:\.\d+)?)', body)
    return float(m.group(1)) if m else None


def places() -> list[dict]:
    rows = []
    for path in sorted(DATA.glob('verified_travel_places*.dart')):
        for body in PHOTO_RE.findall(path.read_text(encoding='utf-8')):
            sid = sf(body, 'id')
            if sid:
                rows.append({'id': sid, 'name': sf(body, 'name'), 'city': sf(body, 'city'), 'lat': nf(body, 'latitude'), 'lng': nf(body, 'longitude'), 'source': str(path.relative_to(ROOT))})
    return rows


def images() -> dict[str, dict]:
    out = {}
    for path in [DATA / 'spot_image_registry.dart', *sorted(DATA.glob('verified_travel_image_registry*.dart'))]:
        if not path.exists():
            continue
        for sid, body in IMAGE_RE.findall(path.read_text(encoding='utf-8')):
            out[sid] = {name: sf(body, name) for name in ('assetPath','networkUrl','sourceName','author','license','sourcePage')}
            out[sid]['registry'] = str(path.relative_to(ROOT))
    return out


def evidence() -> set[str]:
    out = set()
    for path in [DATA / 'spot_coordinate_verification_registry.dart', *sorted(DATA.glob('spot_coordinate_verification_registry_*.dart'))]:
        if path.exists():
            out.update(EVIDENCE_RE.findall(path.read_text(encoding='utf-8')))
    return out


def dims(path: Path):
    if Image is None:
        raise SystemExit('Pillow is required: pip install pillow')
    try:
        with Image.open(path) as im:
            return int(im.width), int(im.height)
    except Exception:
        return None


def main() -> int:
    rows, image_map, evidence_ids = places(), images(), evidence()
    generated_quality = json.loads(QUALITY.read_text(encoding='utf-8')) if QUALITY.exists() else {}
    errors = defaultdict(list)
    counts = Counter(r['id'] for r in rows)
    for sid, count in counts.items():
        if count > 1:
            errors['duplicate_ids'].append({'id': sid, 'count': count})

    by_name, by_coord = defaultdict(list), defaultdict(list)
    for r in rows:
        if not r['name'] or not r['city'] or r['lat'] is None or r['lng'] is None:
            errors['incomplete_places'].append(r); continue
        if not (MIN_LAT <= r['lat'] <= MAX_LAT and MIN_LNG <= r['lng'] <= MAX_LNG):
            errors['invalid_coordinates'].append(r)
        by_name[(norm(r['city']), norm(r['name']))].append(r)
        by_coord[(round(r['lat'], 6), round(r['lng'], 6))].append(r)
    for key, group in by_name.items():
        if len({r['id'] for r in group}) > 1:
            errors['duplicate_place_names'].append({'key': key, 'records': group})
    for key, group in by_coord.items():
        if len({r['id'] for r in group}) > 1:
            errors['duplicate_coordinates'].append({'coordinate': key, 'records': group})

    ids = set(counts)
    errors['missing_coordinate_evidence'].extend(sorted(ids - evidence_ids))
    errors['missing_image_registry'].extend(sorted(ids - set(image_map)))

    checked = 0
    for sid in sorted(ids & set(image_map)):
        info = image_map[sid]
        missing = [x for x in ('networkUrl','sourceName','author','license','sourcePage') if not info[x]]
        if missing:
            errors['missing_image_metadata'].append({'id': sid, 'fields': missing})
        if sid in generated_quality:
            meta = generated_quality[sid]
            w, h = int(meta.get('width') or 0), int(meta.get('height') or 0)
        else:
            asset = info['assetPath']
            if not asset:
                errors['missing_local_asset_path'].append({'id': sid, 'registry': info['registry']}); continue
            path = ROOT / asset
            if not path.exists():
                errors['missing_local_asset_file'].append({'id': sid, 'asset': asset}); continue
            size = dims(path)
            if not size:
                errors['unreadable_image'].append({'id': sid, 'asset': asset}); continue
            w, h = size
        checked += 1
        if max(w, h) < MIN_LONG or min(w, h) < MIN_SHORT:
            errors['low_resolution_images'].append({'id': sid, 'width': w, 'height': h, 'requiredLong': MIN_LONG, 'requiredShort': MIN_SHORT})

    if len(rows) < MIN_SPOTS:
        errors['catalog_size'].append({'actual': len(rows), 'required': MIN_SPOTS, 'missing': MIN_SPOTS-len(rows)})

    errors = {k: v for k, v in errors.items() if v}
    summary = {'verified_places': len(rows), 'required_places': MIN_SPOTS, 'coordinate_evidence': len(evidence_ids), 'image_registry_entries': len(image_map), 'image_quality_checked': checked, 'min_long_edge': MIN_LONG, 'min_short_edge': MIN_SHORT, 'error_counts': {k: len(v) for k, v in sorted(errors.items())}, 'passed': not errors}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({'summary': summary, 'errors': errors}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False, indent=2)); print(f'Audit report: {OUT}')
    return 0 if not errors else 2

if __name__ == '__main__':
    raise SystemExit(main())
