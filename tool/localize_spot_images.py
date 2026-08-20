#!/usr/bin/env python3
"""Download verified travel photos into Flutter assets and wire asset paths.

Only manually verified image registries are processed. Author/license/source
metadata remains in each registry and is also exported to
assets/spots/ATTRIBUTION.md. Auto-search image catalogs are intentionally not
localized because they are not part of the hand-verified travel core.
"""

from __future__ import annotations

import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRIES = [
    ROOT / "lib/data/spot_image_registry.dart",
    ROOT / "lib/data/verified_travel_image_registry.dart",
    ROOT / "lib/data/verified_travel_image_registry_batch2.dart",
    ROOT / "lib/data/verified_travel_image_registry_batch3.dart",
    ROOT / "lib/data/verified_travel_image_registry_batch4.dart",
    ROOT / "lib/data/verified_travel_image_registry_batch5.dart",
]
ASSET_DIR = ROOT / "assets/spots"
ATTRIBUTION = ASSET_DIR / "ATTRIBUTION.md"

ENTRY_RE = re.compile(
    r"(?P<prefix>\s*'(?P<id>[^']+)':\s*SpotImageInfo\(\n)"
    r"(?P<body>.*?)"
    r"(?P<suffix>\n\s*\),)",
    re.DOTALL,
)
FIELD_RE = re.compile(r"^\s*(?P<name>\w+):\s*'(?P<value>.*?)',\s*$", re.MULTILINE)

USER_AGENT = (
    "BestPhotoSpot/1.0 "
    "(https://github.com/turgutburaktan-ops/tbt; contact: turgutburaktan@gmail.com)"
)


def fields(body: str) -> dict[str, str]:
    return {m.group("name"): m.group("value") for m in FIELD_RE.finditer(body)}


def extension_for(url: str) -> str:
    path = url.split("?", 1)[0].lower()
    for ext in (".jpg", ".jpeg", ".png", ".webp"):
        if path.endswith(ext):
            return ".jpg" if ext == ".jpeg" else ext
    return ".jpg"


def download(url: str, destination: Path) -> None:
    last_error: Exception | None = None
    for attempt in range(6):
        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": USER_AGENT,
                "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
                "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.7",
                "Referer": "https://commons.wikimedia.org/",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                content_type = response.headers.get("Content-Type", "")
                data = response.read()
            if not data or not content_type.startswith("image/"):
                raise RuntimeError(
                    f"Expected image from {url}, got {content_type!r} ({len(data)} bytes)"
                )
            destination.write_bytes(data)
            return
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code != 429:
                raise
            retry_after = exc.headers.get("Retry-After") if exc.headers else None
            wait = int(retry_after) if retry_after and retry_after.isdigit() else (4 * (attempt + 1))
            print(f"Wikimedia rate limit: waiting {wait}s before retry {attempt + 2}/6")
            time.sleep(wait)
        except Exception as exc:
            last_error = exc
            if attempt == 5:
                raise
            time.sleep(2 * (attempt + 1))
    if last_error is not None:
        raise last_error


def main() -> int:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    attribution_rows: list[str] = []
    failures: list[str] = []
    downloaded = 0
    localized = 0

    for registry in REGISTRIES:
        if not registry.exists():
            failures.append(f"missing registry: {registry.relative_to(ROOT)}")
            continue

        text = registry.read_text(encoding="utf-8")

        def replace(match: re.Match[str]) -> str:
            nonlocal downloaded, localized
            spot_id = match.group("id")
            body = match.group("body")
            data = fields(body)
            url = data.get("networkUrl", "").strip()
            if not url:
                return match.group(0)

            ext = extension_for(url)
            relative_path = f"assets/spots/{spot_id}{ext}"
            destination = ROOT / relative_path

            try:
                if not destination.exists() or destination.stat().st_size < 1024:
                    print(
                        f"Downloading {registry.name}:{spot_id} -> {relative_path}"
                    )
                    download(url, destination)
                    downloaded += 1
                    time.sleep(1.5)
            except Exception as exc:
                failures.append(f"{registry.name}:{spot_id}: {exc}")
                print(f"ERROR {registry.name}:{spot_id}: {exc}", file=sys.stderr)
                return match.group(0)

            if "assetPath:" in body:
                body = re.sub(
                    r"(^\s*assetPath:\s*').*?(',\s*$)",
                    rf"\g<1>{relative_path}\g<2>",
                    body,
                    count=1,
                    flags=re.MULTILINE,
                )
            else:
                body = f"    assetPath: '{relative_path}',\n" + body.lstrip("\n")

            localized += 1
            attribution_rows.append(
                "\n".join(
                    [
                        f"### `{spot_id}`",
                        f"- Registry: `{registry.relative_to(ROOT)}`",
                        f"- Local asset: `{relative_path}`",
                        f"- Source: {data.get('sourceName', '')}",
                        f"- Author: {data.get('author', '')}",
                        f"- License: {data.get('license', '')}",
                        f"- Source page: {data.get('sourcePage', '')}",
                    ]
                )
            )
            return match.group("prefix") + body + match.group("suffix")

        updated = ENTRY_RE.sub(replace, text)
        registry.write_text(updated, encoding="utf-8")

    header = """# Localized verified travel photo attribution\n\nThese files are local copies of manually verified Wikimedia Commons images\nregistered in the app's verified image registries. Author, license and source\nmetadata is retained here so bundling the images does not lose attribution.\n\n"""
    ATTRIBUTION.write_text(
        header + "\n\n".join(attribution_rows) + "\n", encoding="utf-8"
    )

    print(
        f"Localized registry entries: {localized}; downloaded now: {downloaded}; "
        f"registries: {len(REGISTRIES)}"
    )
    if failures:
        print(
            "Some verified assets could not be localized; successful downloads "
            "will still be kept:",
            file=sys.stderr,
        )
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
