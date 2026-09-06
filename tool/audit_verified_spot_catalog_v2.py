#!/usr/bin/env python3
"""1100-place catalog quality audit with strict generated-image quality.

Generated Wikidata/Commons records must satisfy the full 1600x900 source-image
rule. Older hand-verified records remain real, sourced records; if their Commons
original is smaller, that is reported as a legacy image warning instead of
blocking the nationwide catalog. Coordinate/evidence/image metadata rules stay
fatal for every record.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

import audit_verified_spot_catalog as base

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'lib/data'
QUALITY = DATA / 'verified_travel_image_quality_generated.json'
WARNINGS = ROOT / 'build/spot_quality/legacy_image_warnings.json'
STRICT_LONG = int(os.getenv('MIN_IMAGE_LONG_EDGE', '1600'))
STRICT_SHORT = int(os.getenv('MIN_IMAGE_SHORT_EDGE', '900'))
LEGACY_LONG = int(os.getenv('MIN_LEGACY_IMAGE_LONG_EDGE', '700'))
LEGACY_SHORT = int(os.getenv('MIN_LEGACY_IMAGE_SHORT_EDGE', '450'))


def string_field(body: str, name: str) -> str:
    single = re.search(rf"{name}:\s*'((?:\\'|[^'])*)'", body)
    if single:
        return single.group(1).replace("\\'", "'").strip()
    double = re.search(rf'{name}:\s*"((?:\\"|[^"])*)"', body)
    if double:
        return double.group(1).replace('\\"', '"').strip()
    return ''


def strict_generated_check() -> list[dict]:
    quality = json.loads(QUALITY.read_text(encoding='utf-8')) if QUALITY.exists() else {}
    generated_places = {
        row['id']: row
        for row in base.places()
        if row['source'].endswith('verified_travel_places_generated.dart')
    }
    failures = []
    for sid, meta in quality.items():
        w, h = int(meta.get('width') or 0), int(meta.get('height') or 0)
        if max(w, h) < STRICT_LONG or min(w, h) < STRICT_SHORT:
            failures.append({
                'id': sid,
                'reason': 'low_resolution',
                'width': w,
                'height': h,
            })
        province = str(meta.get('province') or '').strip()
        district = str(meta.get('district') or '').strip()
        province_qid = str(meta.get('provinceQid') or '').strip()
        district_qid = str(meta.get('districtQid') or '').strip()
        if (
            not province
            or not district
            or not province_qid.startswith('Q')
            or not district_qid.startswith('Q')
        ):
            failures.append({
                'id': sid,
                'reason': 'missing_province_or_district_evidence',
                'province': province,
                'provinceQid': province_qid,
                'district': district,
                'districtQid': district_qid,
            })
        place = generated_places.get(sid)
        if place is None:
            failures.append({'id': sid, 'reason': 'missing_generated_place'})
        elif province and base.norm(place['city']) != base.norm(province):
            failures.append({
                'id': sid,
                'reason': 'province_mismatch',
                'placeCity': place['city'],
                'evidenceProvince': province,
            })
    for sid in sorted(set(generated_places) - set(quality)):
        failures.append({'id': sid, 'reason': 'missing_generated_quality_record'})
    return failures


def legacy_warnings() -> list[dict]:
    generated = set(json.loads(QUALITY.read_text(encoding='utf-8'))) if QUALITY.exists() else set()
    image_map = base.images()
    warnings = []
    for sid in sorted(set(r['id'] for r in base.places()) - generated):
        info = image_map.get(sid)
        if not info:
            continue
        asset = info.get('assetPath') or ''
        if not asset:
            continue
        path = ROOT / asset
        size = base.dims(path) if path.exists() else None
        if not size:
            continue
        w, h = size
        if max(w, h) < STRICT_LONG or min(w, h) < STRICT_SHORT:
            warnings.append({'id': sid, 'width': w, 'height': h, 'asset': asset})
    return warnings


base.sf = string_field

if __name__ == '__main__':
    strict_failures = strict_generated_check()
    if strict_failures:
        print(json.dumps({'strict_generated_failures': strict_failures[:50]}, ensure_ascii=False, indent=2))
        raise SystemExit(2)

    warnings = legacy_warnings()
    WARNINGS.parent.mkdir(parents=True, exist_ok=True)
    WARNINGS.write_text(
        json.dumps(
            {
                'strict_generated_threshold': {'long': STRICT_LONG, 'short': STRICT_SHORT},
                'legacy_floor': {'long': LEGACY_LONG, 'short': LEGACY_SHORT},
                'warning_count': len(warnings),
                'warnings': warnings,
            },
            ensure_ascii=False,
            indent=2,
        ) + '\n',
        encoding='utf-8',
    )
    print(f'Legacy image warnings: {len(warnings)} (nonfatal; generated images remain strict)')

    base.MIN_LONG = LEGACY_LONG
    base.MIN_SHORT = LEGACY_SHORT
    raise SystemExit(base.main())
