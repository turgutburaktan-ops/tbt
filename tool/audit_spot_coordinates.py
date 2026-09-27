from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path

DATA_DIR = Path('lib/data')
OUT_DIR = Path('build/spot_quality')
OUT_FILE = OUT_DIR / 'coordinate_audit.json'

VERIFIED_TRAVEL_FILES = sorted(DATA_DIR.glob('verified_travel_places*.dart'))
EVIDENCE_FILES = [
    DATA_DIR / 'spot_coordinate_verification_registry.dart',
    *sorted(DATA_DIR.glob('spot_coordinate_verification_registry_batch*.dart')),
]
IMAGE_FILES = [
    DATA_DIR / 'spot_image_registry.dart',
    *sorted(DATA_DIR.glob('verified_travel_image_registry*.dart')),
]

MIN_LAT, MAX_LAT = 35.4, 42.3
MIN_LNG, MAX_LNG = 25.4, 45.1

FIELD_PATTERNS = {
    'id': re.compile(r"id:\s*'([^']+)'"),
    'name': re.compile(r"name:\s*'([^']+)'"),
    'city': re.compile(r"city:\s*'([^']+)'"),
    'latitude': re.compile(r"latitude:\s*(-?\d+(?:\.\d+)?)"),
    'longitude': re.compile(r"longitude:\s*(-?\d+(?:\.\d+)?)"),
}
COORD_RE = re.compile(
    r"'(?P<id>[^']+)'\s*:\s*SpotCoordinate\(\s*"
    r"(?P<lat>-?\d+(?:\.\d+)?)\s*,\s*(?P<lng>-?\d+(?:\.\d+)?)\s*\)"
)
EVIDENCE_ID_RE = re.compile(
    r"^\s*'([^']+)'\s*:\s*SpotCoordinateVerificationEvidence\(",
    re.MULTILINE,
)
IMAGE_ID_RE = re.compile(
    r"^\s*'([^']+)'\s*:\s*SpotImageInfo\(",
    re.MULTILINE,
)


def photo_spot_bodies(text: str):
    marker = 'PhotoSpot('
    cursor = 0
    while True:
        start = text.find(marker, cursor)
        if start < 0:
            return
        i = start + len(marker)
        depth = 1
        quote = None
        escaped = False
        while i < len(text) and depth > 0:
            ch = text[i]
            if quote is not None:
                if escaped:
                    escaped = False
                elif ch == '\\':
                    escaped = True
                elif ch == quote:
                    quote = None
            else:
                if ch in "'\"":
                    quote = ch
                elif ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
            i += 1
        if depth == 0:
            yield text[start + len(marker): i - 1]
            cursor = i
        else:
            return


def parse_photo_spots(path: Path) -> list[dict]:
    text = path.read_text(encoding='utf-8')
    records: list[dict] = []
    for body in photo_spot_bodies(text):
        record = {'source_file': str(path)}
        for field, pattern in FIELD_PATTERNS.items():
            found = pattern.search(body)
            if not found:
                break
            record[field] = found.group(1)
        else:
            record['latitude'] = float(record['latitude'])
            record['longitude'] = float(record['longitude'])
            records.append(record)
    return records


def parse_coordinate_map(path: Path) -> list[dict]:
    text = path.read_text(encoding='utf-8')
    return [
        {
            'id': m.group('id'),
            'name': '',
            'city': '',
            'latitude': float(m.group('lat')),
            'longitude': float(m.group('lng')),
            'source_file': str(path),
        }
        for m in COORD_RE.finditer(text)
    ]


def parse_registry_ids(path: Path, pattern: re.Pattern[str]) -> set[str]:
    if not path.exists():
        return set()
    return set(pattern.findall(path.read_text(encoding='utf-8')))


def coord_key(item: dict, digits: int = 5) -> str:
    return f"{item['latitude']:.{digits}f}|{item['longitude']:.{digits}f}"


def coordinate_issues(records: list[dict]) -> tuple[list[dict], list[dict]]:
    invalid_bounds: list[dict] = []
    zero_coordinates: list[dict] = []
    for item in records:
        lat = item['latitude']
        lng = item['longitude']
        if lat == 0 or lng == 0:
            zero_coordinates.append(item)
        if not (MIN_LAT <= lat <= MAX_LAT and MIN_LNG <= lng <= MAX_LNG):
            invalid_bounds.append(item)
    return invalid_bounds, zero_coordinates


def main() -> None:
    records: list[dict] = []
    per_file: dict[str, int] = {}
    for path in sorted(DATA_DIR.glob('*.dart')):
        parsed = (
            parse_coordinate_map(path)
            if path.name == 'turkiye81_spot_coordinates.dart'
            else parse_photo_spots(path)
        )
        if parsed:
            per_file[str(path)] = len(parsed)
            records.extend(parsed)

    if not records:
        raise SystemExit('Coordinate audit parsed zero records; parser/data format must be fixed.')
    if not VERIFIED_TRAVEL_FILES:
        raise SystemExit('No verified travel data files found.')

    # Eski/arşiv katalog da raporlanır, fakat kullanıcıya artık çıkmadığı için
    # yalnız doğrulanmış çekirdekteki koordinat kusurları fatal kabul edilir.
    invalid_bounds, zero_coordinates = coordinate_issues(records)

    by_exact = defaultdict(list)
    for item in records:
        by_exact[coord_key(item)].append(item)
    duplicate_coordinates = [
        {'coordinate': key, 'records': group}
        for key, group in sorted(by_exact.items())
        if len({item['id'] for item in group}) > 1
    ]

    by_id = defaultdict(list)
    for item in records:
        by_id[item['id']].append(item)
    duplicate_ids = [
        {'id': item_id, 'records': group}
        for item_id, group in sorted(by_id.items())
        if len(group) > 1
    ]

    verified_travel: list[dict] = []
    for path in VERIFIED_TRAVEL_FILES:
        verified_travel.extend(parse_photo_spots(path))

    verified_ids = {item['id'] for item in verified_travel}
    evidence_ids: set[str] = set()
    for path in EVIDENCE_FILES:
        if not path.exists():
            raise SystemExit(f'Missing coordinate evidence file: {path}')
        evidence_ids.update(parse_registry_ids(path, EVIDENCE_ID_RE))

    image_ids: set[str] = set()
    for path in IMAGE_FILES:
        if not path.exists():
            raise SystemExit(f'Missing verified image file: {path}')
        image_ids.update(parse_registry_ids(path, IMAGE_ID_RE))

    missing_evidence = sorted(verified_ids - evidence_ids)
    missing_images = sorted(verified_ids - image_ids)
    verified_invalid_bounds, verified_zero_coordinates = coordinate_issues(
        verified_travel
    )

    verified_by_coord = defaultdict(list)
    for item in verified_travel:
        verified_by_coord[coord_key(item)].append(item)
    verified_duplicate_coordinates = [
        {'coordinate': key, 'records': group}
        for key, group in sorted(verified_by_coord.items())
        if len({item['id'] for item in group}) > 1
    ]

    verified_by_id = defaultdict(list)
    for item in verified_travel:
        verified_by_id[item['id']].append(item)
    verified_duplicate_ids = [
        {'id': item_id, 'records': group}
        for item_id, group in sorted(verified_by_id.items())
        if len(group) > 1
    ]

    report = {
        'summary': {
            'parsed_records': len(records),
            'parsed_files': len(per_file),
            'verified_travel_files': len(VERIFIED_TRAVEL_FILES),
            'verified_evidence_files': len(EVIDENCE_FILES),
            'verified_image_files': len(IMAGE_FILES),
            'verified_travel_places': len(verified_travel),
            'legacy_and_all_invalid_bounds': len(invalid_bounds),
            'legacy_and_all_zero_coordinates': len(zero_coordinates),
            'legacy_and_all_duplicate_coordinate_groups': len(duplicate_coordinates),
            'legacy_and_all_duplicate_id_groups': len(duplicate_ids),
            'verified_travel_invalid_bounds': len(verified_invalid_bounds),
            'verified_travel_zero_coordinates': len(verified_zero_coordinates),
            'verified_travel_missing_evidence': len(missing_evidence),
            'verified_travel_missing_images': len(missing_images),
            'verified_travel_duplicate_coordinate_groups': len(
                verified_duplicate_coordinates
            ),
            'verified_travel_duplicate_id_groups': len(verified_duplicate_ids),
        },
        'records_per_file': per_file,
        'legacy_and_all': {
            'invalid_bounds': invalid_bounds,
            'zero_coordinates': zero_coordinates,
            'duplicate_coordinates': duplicate_coordinates,
            'duplicate_ids': duplicate_ids,
        },
        'verified_travel': {
            'records': verified_travel,
            'invalid_bounds': verified_invalid_bounds,
            'zero_coordinates': verified_zero_coordinates,
            'missing_evidence_ids': missing_evidence,
            'missing_image_ids': missing_images,
            'duplicate_coordinates': verified_duplicate_coordinates,
            'duplicate_ids': verified_duplicate_ids,
        },
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

    print(json.dumps(report['summary'], ensure_ascii=False, indent=2))
    print(f'Audit report: {OUT_FILE}')

    if (
        verified_invalid_bounds
        or verified_zero_coordinates
        or missing_evidence
        or missing_images
        or verified_duplicate_coordinates
        or verified_duplicate_ids
    ):
        raise SystemExit(2)


if __name__ == '__main__':
    main()
