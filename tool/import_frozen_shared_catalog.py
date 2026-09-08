#!/usr/bin/env python3
"""Import an explicitly reviewed manifest into the shared photo_spots collection.

Dry run is the default. Never deletes or overwrites another publisher's records.
The Firebase credential is supplied by the deployment environment, not this file.
"""
import argparse
import hashlib
import json
import re
from datetime import datetime, timezone, timedelta
from pathlib import Path
from urllib.parse import urlparse

PROJECT = 'en-iyi-cekim-noktasi'


def documents(manifest, digest, expected_count):
    rows = manifest['accepted']
    if len(rows) != expected_count or manifest['acceptedCount'] != expected_count or not rows:
        raise ValueError('Reviewed count mismatch or empty manifest')
    if len(rows) + len(manifest['held']) != manifest['frozenTotal']:
        raise ValueError('Frozen catalog accounting mismatch')
    checked = datetime.fromisoformat(manifest['checkedAt'])
    age = datetime.now(timezone.utc) - checked
    if not timedelta(0) <= age <= timedelta(days=1):
        raise ValueError('Manifest source evidence must be less than 24 hours old')
    docs = {}
    for row in rows:
        sid = row['id']
        if not re.fullmatch(r'[a-z0-9-]+', sid) or sid in docs:
            raise ValueError('Unsafe or duplicate document ID')
        image = urlparse(row['imageUrl'])
        if image.scheme != 'https' or image.hostname not in ('upload.wikimedia.org', 'thumb.wikimedia.org') or image.username or image.password:
            raise ValueError(f'Invalid Wikimedia preview: {sid}')
        if not row['district'] or not row['city'] or not row['name']:
            raise ValueError(f'Missing administrative label: {sid}')
        if not 35.4 <= row['lat'] <= 42.3 or not 25.4 <= row['lng'] <= 45.1:
            raise ValueError(f'Invalid Turkey coordinates: {sid}')
        if max(row['imageWidth'], row['imageHeight']) < 1600 or min(row['imageWidth'], row['imageHeight']) < 900:
            raise ValueError(f'Invalid source size: {sid}')
        docs[sid] = {
            'name': row['name'], 'city': row['city'], 'district': row['district'],
            'latitude': row['lat'], 'longitude': row['lng'],
            'imageUrl': row['imageUrl'], 'imageOriginalUrl': row['imageOriginalUrl'],
            'imageSourcePage': row['imageSourcePage'], 'imageAuthor': row['imageAuthor'],
            'imageLicense': row['imageLicense'], 'imageLicenseUrl': row['imageLicenseUrl'],
            'imageWidth': row['imageWidth'], 'imageHeight': row['imageHeight'],
            'wikidataQid': row['wikidataQid'], 'provinceQid': row['provinceQid'],
            'districtQid': row['districtQid'], 'verifiedAt': row['checkedAt'],
            'status': 'published', 'coordinateVerified': True, 'imageVerified': True,
            'catalogPublisher': 'tbt-frozen-shared-v1', 'catalogManifestSha256': digest,
            'category': row.get('category', 'Genel'), 'rating': 0,
            'tags': ['Gezilecek Yer', 'Doğrulanmış', row['city'], row['district']],
        }
    return docs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--expected-count', required=True, type=int)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    raw = args.manifest.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != args.sha256:
        raise SystemExit('Reviewed manifest digest mismatch')
    docs = documents(json.loads(raw), digest, args.expected_count)
    from google.cloud import firestore
    client = firestore.Client(project=PROJECT)
    collection = client.collection('photo_spots')
    existing = {snap.id: snap.to_dict() for snap in collection.stream()}
    conflicts = [sid for sid, data in existing.items() if sid in docs and data != docs[sid]]
    if conflicts:
        raise SystemExit(f'Import stopped: {len(conflicts)} existing records differ; no writes performed')
    pending = sorted(set(docs) - set(existing))
    print(json.dumps({'mode': 'apply' if args.apply else 'dry-run', 'reviewed': len(docs),
        'create': len(pending), 'alreadyExact': len(docs)-len(pending),
        'unrelatedPreserved': len(set(existing)-set(docs)), 'manifestSha256': digest}), flush=True)
    if not args.apply:
        return
    for start in range(0, len(pending), 200):
        batch = client.batch()
        for sid in pending[start:start+200]:
            # Atomic create preconditions prevent overwriting concurrent admin edits.
            batch.create(collection.document(sid), docs[sid])
        batch.commit()
        print(f'Created {min(start+200, len(pending))}/{len(pending)}', flush=True)
    actual = {snap.id: snap.to_dict() for snap in collection.stream()}
    if any(actual.get(sid) != data for sid, data in docs.items()):
        raise SystemExit('Post-import verification failed; do not release the readers')
    print(json.dumps({'verifiedPublishedCount': len(docs), 'manifestSha256': digest,
        'unrelatedPreserved': len(set(actual)-set(docs))}), flush=True)


if __name__ == '__main__':
    main()
