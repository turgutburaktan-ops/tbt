#!/usr/bin/env python3
"""Download verified spot photos into Flutter assets and wire registry asset paths.

Only entries already present in lib/data/spot_image_registry.dart are processed.
Their author/license/source metadata stays in the registry and is also exported to
assets/spots/ATTRIBUTION.md. No camera/Iris code is touched.
"""

from __future__ import annotations

import re
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "lib/data/spot_image_registry.dart"
ASSET_DIR = ROOT / "assets/spots"
ATTRIBUTION = ASSET_DIR / "ATTRIBUTION.md"

ENTRY_RE = re.compile(
    r"(?P<prefix>\s*'(?P<id>[^']+)':\s*SpotImageInfo\(\n)"
    r"(?P<body>.*?)"
    r"(?P<suffix>\n\s*\),)",
    re.DOTALL,
)
FIELD_RE = re.compile(r"^\s*(?P<name>\w+):\s*'(?P<value>.*?)',\s*$", re.MULTILINE)


def fields(body: str) -> dict[str, str]:
    return {m.group("name"): m.group("value") for m in FIELD_RE.finditer(body)}


def extension_for(url: str) -> str:
    path = url.split("?", 1)[0].lower()
    for ext in (".jpg", ".jpeg", ".png", ".webp"):
        if path.endswith(ext):
            return ".jpg" if ext == ".jpeg" else ext
    return ".jpg"


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "BestPhotoSpot/0.1 verified-asset-localizer (GitHub Actions)",
            "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        content_type = response.headers.get("Content-Type", "")
        data = response.read()
    if not data or not content_type.startswith("image/"):
        raise RuntimeError(f"Expected image from {url}, got {content_type!r} ({len(data)} bytes)")
    destination.write_bytes(data)


def main() -> int:
    text = REGISTRY.read_text(encoding="utf-8")
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    attribution_rows: list[str] = []
    failures: list[str] = []
    downloaded = 0

    def replace(match: re.Match[str]) -> str:
        nonlocal downloaded
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
                print(f"Downloading {spot_id} -> {relative_path}")
                download(url, destination)
                downloaded += 1
                time.sleep(0.2)
        except Exception as exc:  # keep other verified assets progressing
            failures.append(f"{spot_id}: {exc}")
            print(f"ERROR {spot_id}: {exc}", file=sys.stderr)
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

        attribution_rows.append(
            "\n".join(
                [
                    f"### `{spot_id}`",
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
    REGISTRY.write_text(updated, encoding="utf-8")

    header = """# Localized spot photo attribution\n\nThese files are local copies of the already verified Wikimedia Commons images\nregistered in `lib/data/spot_image_registry.dart`. Author and license details are\nkept here so bundling the files does not lose attribution metadata.\n\n"""
    ATTRIBUTION.write_text(header + "\n\n".join(attribution_rows) + "\n", encoding="utf-8")

    print(f"Localized registry entries: {len(attribution_rows)}; downloaded now: {downloaded}")
    if failures:
        print("Some assets could not be localized:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
