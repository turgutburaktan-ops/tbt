#!/usr/bin/env python3
"""Rate-limit-safe high-resolution upgrade for hand-verified spot photos.

Generated 1000+ entries remain network-backed. Hand-verified local assets are
upgraded from Wikimedia Commons where a larger real source exists. If Commons'
original file itself is below the desired display threshold, that is a source
limitation warning rather than a transport failure; no fake upscaling is done.
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
        p for p in sorted(DATA.glob('verified_travel_image_registry*.dart'))
        if p.name != 'verified_travel_image_registry_generated.dart'
    ],
]
COMMONS_API = 'https://commons.wikimedia.org/w/api.php'
UA = 'BestPhotoSpotImageUpgrade/2.1 (https://github.com/turgutburaktan-ops/tbt)'
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
        request = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'application/json,*/*;q=0.8'})
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
        batch_keys = keys[offset:offset + 30]
        titles = [title_value[key] for key in batch_keys]
        payload = get_json({
            'action': 'query', 'format': 'json', 'formatversion': '2',
            'prop': 'imageinfo', 'iiprop': 'url|size|mime',
            'iiurlwidth': str(request_width), 'titles': '|'.join(titles),
        })
        for page in payload.get('query', {}).get('pages', []):
            infos = page.get('imageinfo') or []
            if not infos:
                continue
            info = infos[0]
            key = title_key(page.get('title', ''))
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
            }
            for sid in ids:
                resolved[sid] = meta
        time.sleep(1.0)
    return resolved


def download_bytes(url: str, attempts: int = 7) -> bytes:
    last: Exception | None = None
    for attempt in range(attempts):
        request = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'image/*,*/*;q=0.8'})
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
        tmp.write(data); tmp.flush(); return image_size(Path(tmp.name))


def collect_low_res(long_edge: int, short_edge: int) -> tuple[int, list[dict]]:
    checked = 0; pending = []
    for registry in REGISTRIES:
        if not registry.exists():
            continue
        text = registry.read_text(encoding='utf-8')
        for sid, body in ENTRY_RE.findall(text):
            asset, network_url = field(body, 'assetPath'), field(body, 'networkUrl')
            source_page = field(body, 'sourcePage')
            if not asset or not network_url:
                continue
            checked += 1
            path = ROOT / asset
            current = image_size(path) if path.exists() else None
            if good(current, long_edge, short_edge):
                continue
            pending.append({'id': sid, 'asset': asset, 'path': path, 'networkUrl': network_url, 'sourcePage': source_page, 'current': current})
    return checked, pending


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--long-edge', type=int, default=1600)
    parser.add_argument('--short-edge', type=int, default=900)
    parser.add_argument('--request-width', type=int, default=2560)
    parser.add_argument('--download-delay', type=float, default=1.15)
    args = parser.parse_args()

    checked, pending = collect_low_res(args.long_edge, args.short_edge)
    print(f'Checked {checked}; need upgrade {len(pending)}')
    if not pending:
        return 0

    time.sleep(5.0)
    try:
        resolved = resolve_high_res_urls(pending, args.request_width)
    except Exception as exc:
        print(f'Fatal Commons metadata error: {exc}')
        return 2

    upgraded = 0
    limitations: list[str] = []
    hard_failures: list[str] = []
    for entry in pending:
        sid = entry['id']
        meta = resolved.get(sid)
        if not meta or not meta.get('url'):
            hard_failures.append(f'{sid}: no Commons high-resolution URL resolved')
            continue
        source_size = (meta.get('width', 0), meta.get('height', 0))
        if not good(source_size, args.long_edge, args.short_edge):
            limitations.append(f'{sid}: Commons original itself is too small: {source_size}')
            continue
        try:
            print(f"Upgrading {sid}: {entry['current']} -> {meta['url']}")
            data = download_bytes(meta['url'])
            fresh = verified_temp_size(data)
            if not good(fresh, args.long_edge, args.short_edge):
                limitations.append(f'{sid}: downloaded image remains source/aspect limited: {fresh}')
                continue
            entry['path'].parent.mkdir(parents=True, exist_ok=True)
            entry['path'].write_bytes(data)
            upgraded += 1
            time.sleep(args.download_delay)
        except Exception as exc:
            hard_failures.append(f'{sid}: {exc}')

    print(f'Checked {checked}; upgraded {upgraded}; source-limit warnings {len(limitations)}; hard failures {len(hard_failures)}')
    for item in limitations:
        print(f'WARN - {item}')
    for item in hard_failures:
        print(f'ERROR - {item}')
    return 2 if hard_failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
