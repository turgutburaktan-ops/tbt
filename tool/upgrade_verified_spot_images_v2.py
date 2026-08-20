#!/usr/bin/env python3
"""Rate-limit-safe high-resolution upgrade for hand-verified spot photos.

Generated 1000+ entries remain network-backed. Only hand-verified assets that
are below the requested display threshold are upgraded. Wikimedia Commons file
metadata is resolved in batches and image bytes are downloaded from the direct
upload host with retry/backoff. A low-resolution download never overwrites the
existing asset.
"""
from __future__ import annotations

import argparse
import json
import re
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'lib/data'
REGISTRIES = [
    DATA / 'spot_image_registry.dart',
    *[
        p
        for p in sorted(DATA.glob('verified_travel_image_registry*.dart'))
        if p.name != 'verified_travel_image_registry_generated.dart'
    ],
]
COMMONS_API = 'https://commons.wikimedia.org/w/api.php'
UA = 'BestPhotoSpotImageUpgrade/2.0 (https://github.com/turgutburaktan-ops/tbt)'
ENTRY_RE = re.compile(
    r"^\s*'([^']+)'\s*:\s*SpotImageInfo\((.*?)\n\s*\),",
    re.MULTILINE | re.DOTALL,
)


def field(body: str, name: str) -> str:
    single = re.search(rf"{name}:\s*'((?:\\'|[^'])*)'", body)
    if single:
        return single.group(1).replace("\\'", "'").strip()
    double = re.search(rf'{name}:\s*"((?:\\"|[^"])*)"', body)
    if double:
        return double.group(1).replace('\\"', '"').strip()
    return ''


def image_size(path: Path):
    try:
        with Image.open(path) as im:
            return int(im.width), int(im.height)
    except Exception:
        return None


def good(size, long_edge: int, short_edge: int) -> bool:
    return bool(size) and max(size) >= long_edge and min(size) >= short_edge


def title_key(value: str) -> str:
    return urllib.parse.unquote(value).replace('_', ' ').strip().casefold()


def commons_title(source_page: str, network_url: str) -> str:
    if '/wiki/File:' in source_page:
        tail = source_page.split('/wiki/File:', 1)[1]
        return 'File:' + urllib.parse.unquote(tail).replace('_', ' ')
    marker = '/wiki/Special:Redirect/file/'
    if marker in network_url:
        tail = urllib.parse.urlsplit(network_url).path.split(marker, 1)[1]
        return 'File:' + urllib.parse.unquote(tail).replace('_', ' ')
    return ''


def retry_delay(exc: Exception, attempt: int) -> float:
    if isinstance(exc, urllib.error.HTTPError):
        raw = exc.headers.get('Retry-After') if exc.headers else None
        if raw:
            try:
                return min(90.0, max(2.0, float(raw)))
            except ValueError:
                pass
    return min(60.0, 2.0 * (2 ** attempt))


def get_json(params: dict[str, str], attempts: int = 7) -> dict:
    url = COMMONS_API + '?' + urllib.parse.urlencode(params)
    last: Exception | None = None
    for attempt in range(attempts):
        request = urllib.request.Request(
            url,
            headers={'User-Agent': UA, 'Accept': 'application/json,*/*;q=0.8'},
        )
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.loads(response.read().decode('utf-8'))
        except urllib.error.HTTPError as exc:
            last = exc
            if exc.code not in (429, 500, 502, 503, 504):
                raise
        except Exception as exc:
            last = exc
        if attempt + 1 < attempts:
            time.sleep(retry_delay(last, attempt))
    raise RuntimeError(f'Commons metadata request failed: {last}')


def resolve_high_res_urls(entries: list[dict], request_width: int) -> dict[str, dict]:
    title_to_ids: dict[str, list[str]] = {}
    title_value: dict[str, str] = {}
    for entry in entries:
        title = commons_title(entry['sourcePage'], entry['networkUrl'])
        if not title:
            continue
        key = title_key(title)
        title_to_ids.setdefault(key, []).append(entry['id'])
        title_value[key] = title

    resolved: dict[str, dict] = {}
    keys = sorted(title_value)
    for offset in range(0, len(keys), 30):
        batch_keys = keys[offset : offset + 30]
        titles = [title_value[key] for key in batch_keys]
        payload = get_json(
            {
                'action': 'query',
                'format': 'json',
                'formatversion': '2',
                'prop': 'imageinfo',
                'iiprop': 'url|size|mime',
                'iiurlwidth': str(request_width),
                'titles': '|'.join(titles),
            }
        )
        for page in payload.get('query', {}).get('pages', []):
            infos = page.get('imageinfo') or []
            if not infos:
                continue
            info = infos[0]
            key = title_key(page.get('title', ''))
            # MediaWiki can normalize titles; fall back to filename matching.
            ids = title_to_ids.get(key, [])
            if not ids:
                page_name = key.removeprefix('file:')
                for candidate_key, candidate_ids in title_to_ids.items():
                    if candidate_key.removeprefix('file:') == page_name:
                        ids = candidate_ids
                        break
            meta = {
                'url': info.get('thumburl') or info.get('url') or '',
                'original_url': info.get('url') or '',
                'width': int(info.get('width') or 0),
                'height': int(info.get('height') or 0),
                'thumbwidth': int(info.get('thumbwidth') or 0),
                'thumbheight': int(info.get('thumbheight') or 0),
            }
            for sid in ids:
                resolved[sid] = meta
        time.sleep(1.0)
    return resolved


def download_bytes(url: str, attempts: int = 7) -> bytes:
    last: Exception | None = None
    for attempt in range(attempts):
        request = urllib.request.Request(
            url,
            headers={'User-Agent': UA, 'Accept': 'image/*,*/*;q=0.8'},
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                data = response.read()
            if not data:
                raise RuntimeError('empty response')
            return data
        except urllib.error.HTTPError as exc:
            last = exc
            if exc.code not in (429, 500, 502, 503, 504):
                raise
        except Exception as exc:
            last = exc
        if attempt + 1 < attempts:
            time.sleep(retry_delay(last, attempt))
    raise RuntimeError(f'image download failed after retries: {last}')


def verified_temp_size(data: bytes):
    with tempfile.NamedTemporaryFile(suffix='.img', delete=True) as tmp:
        tmp.write(data)
        tmp.flush()
        return image_size(Path(tmp.name))


def collect_low_res(long_edge: int, short_edge: int) -> tuple[int, list[dict]]:
    checked = 0
    pending: list[dict] = []
    for registry in REGISTRIES:
        if not registry.exists():
            continue
        text = registry.read_text(encoding='utf-8')
        for sid, body in ENTRY_RE.findall(text):
            asset = field(body, 'assetPath')
            network_url = field(body, 'networkUrl')
            source_page = field(body, 'sourcePage')
            if not asset or not network_url:
                continue
            checked += 1
            path = ROOT / asset
            current = image_size(path) if path.exists() else None
            if good(current, long_edge, short_edge):
                continue
            pending.append(
                {
                    'id': sid,
                    'asset': asset,
                    'path': path,
                    'networkUrl': network_url,
                    'sourcePage': source_page,
                    'current': current,
                }
            )
    return checked, pending


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--long-edge', type=int, default=1600)
    parser.add_argument('--short-edge', type=int, default=900)
    parser.add_argument('--request-width', type=int, default=1920)
    parser.add_argument('--download-delay', type=float, default=1.15)
    args = parser.parse_args()

    checked, pending = collect_low_res(args.long_edge, args.short_edge)
    print(f'Checked {checked}; need upgrade {len(pending)}')
    if not pending:
        return 0

    # Give Wikimedia a short cooldown after the generator's batched metadata pass.
    time.sleep(8.0)
    resolved = resolve_high_res_urls(pending, args.request_width)

    upgraded = 0
    failures: list[str] = []
    for entry in pending:
        sid = entry['id']
        meta = resolved.get(sid)
        if not meta or not meta.get('url'):
            failures.append(f'{sid}: no Commons high-resolution URL resolved')
            continue
        source_size = (meta.get('width', 0), meta.get('height', 0))
        if not good(source_size, args.long_edge, args.short_edge):
            failures.append(
                f'{sid}: Commons original itself is too small: {source_size}'
            )
            continue
        try:
            print(f"Upgrading {sid}: {entry['current']} -> {meta['url']}")
            data = download_bytes(meta['url'])
            fresh = verified_temp_size(data)
            if not good(fresh, args.long_edge, args.short_edge):
                raise RuntimeError(f'downloaded image still below threshold: {fresh}')
            entry['path'].parent.mkdir(parents=True, exist_ok=True)
            entry['path'].write_bytes(data)
            upgraded += 1
            time.sleep(args.download_delay)
        except Exception as exc:
            failures.append(f'{sid}: {exc}')

    print(f'Checked {checked}; upgraded {upgraded}; failures {len(failures)}')
    for failure in failures:
        print(f'- {failure}')
    return 2 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
