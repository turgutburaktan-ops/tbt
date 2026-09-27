#!/usr/bin/env python3
"""Upgrade hand-verified local spot photos to phone-display high resolution.

Generated 1000+ entries stay network-backed so the APK does not balloon.
"""
from __future__ import annotations

import argparse
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'lib/data'
REGISTRIES = [DATA / 'spot_image_registry.dart', *[p for p in sorted(DATA.glob('verified_travel_image_registry*.dart')) if p.name != 'verified_travel_image_registry_generated.dart']]
UA = 'BestPhotoSpotImageUpgrade/1.0 (https://github.com/turgutburaktan-ops/tbt)'
ENTRY_RE = re.compile(r"^\s*'([^']+)'\s*:\s*SpotImageInfo\((.*?)\n\s*\),", re.MULTILINE | re.DOTALL)


def field(body: str, name: str) -> str:
    m = re.search(rf"{name}:\s*'([^']*)'", body)
    return m.group(1).strip() if m else ''


def upgraded_url(url: str, width: int) -> str:
    if 'commons.wikimedia.org/wiki/Special:Redirect/file/' not in url:
        return url
    parts = urllib.parse.urlsplit(url)
    query = urllib.parse.parse_qs(parts.query)
    query['width'] = [str(width)]
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc, parts.path, urllib.parse.urlencode(query, doseq=True), parts.fragment))


def size(path: Path):
    try:
        with Image.open(path) as im:
            return int(im.width), int(im.height)
    except Exception:
        return None


def good(s, long_edge: int, short_edge: int) -> bool:
    return bool(s) and max(s) >= long_edge and min(s) >= short_edge


def download(url: str, path: Path) -> None:
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'image/*,*/*;q=0.8'})
    with urllib.request.urlopen(req, timeout=90) as response:
        data = response.read()
    if not data:
        raise RuntimeError(f'empty image: {url}')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def main() -> int:
    ap = argparse.ArgumentParser(); ap.add_argument('--long-edge', type=int, default=1600); ap.add_argument('--short-edge', type=int, default=900); ap.add_argument('--request-width', type=int, default=1920); args = ap.parse_args()
    checked = upgraded = 0; failures = []
    for registry in REGISTRIES:
        if not registry.exists():
            continue
        for sid, body in ENTRY_RE.findall(registry.read_text(encoding='utf-8')):
            asset, url = field(body, 'assetPath'), field(body, 'networkUrl')
            if not asset or not url:
                continue
            checked += 1; path = ROOT / asset; current = size(path) if path.exists() else None
            if good(current, args.long_edge, args.short_edge):
                continue
            try:
                target = upgraded_url(url, args.request_width)
                print(f'Upgrading {sid}: {current} -> {target}')
                download(target, path); upgraded += 1
                fresh = size(path)
                if not good(fresh, args.long_edge, args.short_edge):
                    raise RuntimeError(f'still low resolution after download: {fresh}')
                time.sleep(.7)
            except Exception as exc:
                failures.append(f'{sid}: {exc}')
    print(f'Checked {checked}; upgraded {upgraded}; failures {len(failures)}')
    for failure in failures:
        print(f'- {failure}')
    return 2 if failures else 0

if __name__ == '__main__':
    raise SystemExit(main())
