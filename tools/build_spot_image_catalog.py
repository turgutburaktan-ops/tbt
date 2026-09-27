#!/usr/bin/env python3
"""Build a local, licensed photo catalog for every production photo spot.

The script scans every PhotoSpot and OfficialSpotCandidate under lib/data,
resolves an image from Wikimedia Commons / Turkish Wikipedia / Wikidata, downloads
an optimized Wikimedia thumbnail into assets/spots, and generates a Dart
registry with attribution metadata.

It intentionally never uses Google Images or unlicensed hotlinks.
"""

from __future__ import annotations

import glob
import html
import json
import os
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "lib" / "data"
ASSET_DIR = ROOT / "assets" / "spots"
MANUAL_REGISTRY = DATA_DIR / "spot_image_registry.dart"
AUTO_REGISTRY = DATA_DIR / "spot_image_auto_registry.dart"
REPORT_PATH = ROOT / "tools" / "spot_image_catalog_report.json"
COORDS_PATH = DATA_DIR / "turkiye81_spot_coordinates.dart"
USER_AGENT = "BestPhotoSpot/0.3 (licensed nationwide spot image catalog; GitHub Actions)"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def constructor_blocks(text: str, constructor: str):
    needle = constructor + "("
    start = 0
    while True:
        pos = text.find(needle, start)
        if pos < 0:
            return
        i = pos + len(constructor)
        depth = 0
        quote = None
        escaped = False
        while i < len(text):
            ch = text[i]
            if quote is not None:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == quote:
                    quote = None
            else:
                if ch in ("'", '"'):
                    quote = ch
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        yield text[pos : i + 1]
                        start = i + 1
                        break
            i += 1
        else:
            return


def string_field(block: str, name: str) -> str:
    match = re.search(rf"\b{re.escape(name)}\s*:\s*'((?:\\.|[^'])*)'", block, re.S)
    if not match:
        match = re.search(rf'\b{re.escape(name)}\s*:\s*"((?:\\.|[^"])*)"', block, re.S)
    if not match:
        return ""
    raw = match.group(1)
    return raw.replace("\\'", "'").replace('\\"', '"').replace("\\n", " ").strip()


def number_field(block: str, name: str):
    match = re.search(rf"\b{re.escape(name)}\s*:\s*(-?\d+(?:\.\d+)?)", block)
    return float(match.group(1)) if match else None


def load_coordinates():
    if not COORDS_PATH.exists():
        return {}
    text = read_text(COORDS_PATH)
    coords = {}
    for match in re.finditer(
        r"'([^']+)'\s*:\s*SpotCoordinate\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)",
        text,
    ):
        coords[match.group(1)] = (float(match.group(2)), float(match.group(3)))
    return coords


def collect_spots():
    coords = load_coordinates()
    by_id = {}
    for filename in sorted(glob.glob(str(DATA_DIR / "*.dart"))):
        path = Path(filename)
        if path.name in {"spot_image_registry.dart", "spot_image_auto_registry.dart"}:
            continue
        text = read_text(path)
        for constructor in ("PhotoSpot", "OfficialSpotCandidate"):
            for block in constructor_blocks(text, constructor):
                spot_id = string_field(block, "id")
                name = string_field(block, "name")
                city = string_field(block, "city")
                if not spot_id or not name or not city:
                    continue
                lat = number_field(block, "latitude")
                lon = number_field(block, "longitude")
                if (lat is None or lon is None) and spot_id in coords:
                    lat, lon = coords[spot_id]
                record = {
                    "id": spot_id,
                    "name": name,
                    "city": city,
                    "latitude": lat,
                    "longitude": lon,
                    "sourceFile": path.name,
                    "constructor": constructor,
                }
                previous = by_id.get(spot_id)
                if previous is None or (previous["latitude"] is None and lat is not None):
                    by_id[spot_id] = record
    return sorted(by_id.values(), key=lambda item: (item["city"], item["name"], item["id"]))


def manual_ids():
    if not MANUAL_REGISTRY.exists():
        return set()
    return set(re.findall(r"^\s*'([^']+)'\s*:\s*SpotImageInfo\(", read_text(MANUAL_REGISTRY), re.M))


def normalize(value: str) -> str:
    value = value.lower()
    value = value.translate(str.maketrans({"ı": "i", "ş": "s", "ğ": "g", "ü": "u", "ö": "o", "ç": "c", "İ": "i"}))
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def english_expansion(value: str) -> str:
    text = " " + normalize(value) + " "
    replacements = {
        " antik kenti ": " ancient city ",
        " camii ": " mosque ",
        " cami ": " mosque ",
        " kilisesi ": " church ",
        " kilise ": " church ",
        " kalesi ": " castle ",
        " kale ": " castle ",
        " koprusu ": " bridge ",
        " kopru ": " bridge ",
        " golu ": " lake ",
        " dagi ": " mountain ",
        " dag ": " mountain ",
        " vadisi ": " valley ",
        " sarayi ": " palace ",
        " saray ": " palace ",
        " muzesi ": " museum ",
        " muze ": " museum ",
        " selalesi ": " waterfall ",
        " magarasi ": " cave ",
        " plaji ": " beach ",
        " manastiri ": " monastery ",
        " turbesi ": " tomb ",
        " carsisi ": " bazaar ",
        " koyu ": " bay ",
    }
    for source, target in replacements.items():
        text = text.replace(source, target)
    return re.sub(r"\s+", " ", text).strip()


IGNORED = {
    "ve", "ile", "the", "eski", "tarihi", "historic", "merkezi", "merkez",
    "cevresi", "cevre", "noktasi", "fotograf", "seyir", "milli", "parki",
}


def tokens(value: str):
    return {token for token in normalize(value).split() if len(token) >= 3 and token not in IGNORED}


def title_score(title: str, spot) -> int:
    title_n = normalize(title)
    if not title_n:
        return 0
    candidates = tokens(spot["name"]) | tokens(english_expansion(spot["name"]))
    score = 0
    for token in candidates:
        if token in title_n:
            score += 5 if len(token) >= 5 else 3
    city = normalize(spot["city"])
    if city and city in title_n:
        score += 2
    if "turkey" in title_n or "turkiye" in title_n:
        score += 1
    return score


def api_json(host: str, params: dict, timeout: int = 15):
    query = urllib.parse.urlencode(params)
    req = urllib.request.Request(
        f"https://{host}/w/api.php?{query}",
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            if response.status != 200:
                return None
            return json.loads(response.read().decode("utf-8"))
    except Exception:
        return None


def ext_value(info: dict, key: str) -> str:
    ext = info.get("extmetadata") or {}
    value = ext.get(key) or {}
    if isinstance(value, dict):
        return str(value.get("value") or "").strip()
    return ""


def clean_html(value: str) -> str:
    value = re.sub(r"<[^>]+>", " ", value or "")
    return re.sub(r"\s+", " ", html.unescape(value)).strip()


def image_record_from_info(info: dict, title: str):
    url = str(info.get("thumburl") or info.get("url") or "").strip()
    if not url.startswith("https://"):
        return None
    lower = url.lower()
    if any(ext in lower for ext in (".svg", ".pdf", ".djvu", ".tif", ".tiff")):
        return None
    return {
        "networkUrl": url,
        "sourceName": "Wikimedia Commons",
        "author": clean_html(ext_value(info, "Artist")) or "Wikimedia Commons contributor",
        "license": clean_html(ext_value(info, "LicenseShortName")) or "Wikimedia Commons free media",
        "sourcePage": str(info.get("descriptionurl") or "").strip() or f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(title.replace(' ', '_'))}",
        "sourceTitle": title,
    }


def commons_search(query: str, spot):
    data = api_json("commons.wikimedia.org", {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": "25",
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": "900",
        "format": "json",
        "formatversion": "2",
    })
    pages = ((data or {}).get("query") or {}).get("pages") or []
    ranked = sorted((p for p in pages if isinstance(p, dict)), key=lambda p: title_score(str(p.get("title") or ""), spot), reverse=True)
    for page in ranked:
        score = title_score(str(page.get("title") or ""), spot)
        if score < 4:
            continue
        infos = page.get("imageinfo") or []
        if not infos or not isinstance(infos[0], dict):
            continue
        record = image_record_from_info(infos[0], str(page.get("title") or ""))
        if record:
            record["matchScore"] = score
            record["resolver"] = "commons-search"
            return record
    return None


def commons_file_info(filename: str):
    if not filename:
        return None
    title = filename if filename.startswith("File:") else f"File:{filename}"
    data = api_json("commons.wikimedia.org", {
        "action": "query",
        "titles": title,
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": "900",
        "format": "json",
        "formatversion": "2",
    })
    pages = ((data or {}).get("query") or {}).get("pages") or []
    for page in pages:
        infos = page.get("imageinfo") or []
        if infos and isinstance(infos[0], dict):
            return image_record_from_info(infos[0], str(page.get("title") or title))
    return None


def wikipedia_search(query: str, spot):
    data = api_json("tr.wikipedia.org", {
        "action": "query",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "0",
        "gsrlimit": "10",
        "prop": "pageimages",
        "piprop": "name",
        "format": "json",
        "formatversion": "2",
    })
    pages = ((data or {}).get("query") or {}).get("pages") or []
    ranked = sorted((p for p in pages if isinstance(p, dict)), key=lambda p: title_score(str(p.get("title") or ""), spot), reverse=True)
    for page in ranked:
        score = title_score(str(page.get("title") or ""), spot)
        if score < 4:
            continue
        filename = str(page.get("pageimage") or "").strip()
        record = commons_file_info(filename)
        if record:
            record["matchScore"] = score
            record["resolver"] = "tr-wikipedia-pageimage"
            return record
    return None


def wikidata_search(spot):
    data = api_json("www.wikidata.org", {
        "action": "wbsearchentities",
        "search": spot["name"],
        "language": "tr",
        "uselang": "tr",
        "type": "item",
        "limit": "8",
        "format": "json",
    })
    results = (data or {}).get("search") or []
    ranked = []
    for item in results:
        label = str(item.get("label") or "")
        description = str(item.get("description") or "")
        score = title_score(label + " " + description, spot)
        ranked.append((score, item))
    for score, item in sorted(ranked, key=lambda pair: pair[0], reverse=True):
        if score < 4:
            continue
        qid = str(item.get("id") or "")
        entity_data = api_json("www.wikidata.org", {
            "action": "wbgetentities",
            "ids": qid,
            "props": "claims",
            "format": "json",
        })
        entity = ((entity_data or {}).get("entities") or {}).get(qid) or {}
        claims = entity.get("claims") or {}
        p18 = claims.get("P18") or []
        for claim in p18[:2]:
            try:
                filename = claim["mainsnak"]["datavalue"]["value"]
            except Exception:
                continue
            record = commons_file_info(str(filename))
            if record:
                record["matchScore"] = score
                record["resolver"] = "wikidata-p18"
                return record
    return None


def commons_geo_search(spot):
    lat, lon = spot.get("latitude"), spot.get("longitude")
    if lat is None or lon is None:
        return None
    data = api_json("commons.wikimedia.org", {
        "action": "query",
        "generator": "geosearch",
        "ggsprimary": "all",
        "ggsnamespace": "6",
        "ggsradius": "2500",
        "ggslimit": "50",
        "ggscoord": f"{lat}|{lon}",
        "prop": "imageinfo",
        "iiprop": "url|extmetadata",
        "iiurlwidth": "900",
        "format": "json",
        "formatversion": "2",
    })
    pages = ((data or {}).get("query") or {}).get("pages") or []
    ranked = sorted((p for p in pages if isinstance(p, dict)), key=lambda p: title_score(str(p.get("title") or ""), spot), reverse=True)
    for page in ranked:
        score = title_score(str(page.get("title") or ""), spot)
        if score < 4:
            continue
        infos = page.get("imageinfo") or []
        if not infos or not isinstance(infos[0], dict):
            continue
        record = image_record_from_info(infos[0], str(page.get("title") or ""))
        if record:
            record["matchScore"] = score
            record["resolver"] = "commons-nearby"
            return record
    return None


def query_variants(spot):
    name = spot["name"].strip()
    city = spot["city"].strip()
    expanded = english_expansion(name)
    candidates = [
        f"{name} {city}",
        f"{name} Türkiye",
        f"{name} Turkey",
        name,
    ]
    if normalize(expanded) != normalize(name):
        candidates.extend([f"{expanded} {city} Turkey", expanded])
    seen = set()
    output = []
    for value in candidates:
        key = normalize(value)
        if key and key not in seen:
            seen.add(key)
            output.append(value)
    return output


def resolve_spot(spot):
    queries = query_variants(spot)
    for query in queries:
        record = commons_search(query, spot)
        if record:
            return record
        time.sleep(0.05)
    for query in queries[:4]:
        record = wikipedia_search(query, spot)
        if record:
            return record
        time.sleep(0.05)
    record = wikidata_search(spot)
    if record:
        return record
    return commons_geo_search(spot)


def safe_id(value: str) -> str:
    value = normalize(value).replace(" ", "-")
    return re.sub(r"[^a-z0-9-]+", "", value)[:110] or "spot"


def download_image(url: str, spot_id: str):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "image/*"})
    try:
        with urllib.request.urlopen(req, timeout=25) as response:
            content_type = (response.headers.get("Content-Type") or "").split(";", 1)[0].lower()
            if not content_type.startswith("image/"):
                return None
            data = response.read(2_500_001)
            if len(data) < 2_000 or len(data) > 2_500_000:
                return None
    except Exception:
        return None

    ext = {
        "image/jpeg": "jpg",
        "image/jpg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
    }.get(content_type, "jpg")
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    path = ASSET_DIR / f"auto-{safe_id(spot_id)}.{ext}"
    path.write_bytes(data)
    return path.relative_to(ROOT).as_posix()


def load_previous_entries():
    if not REPORT_PATH.exists():
        return {}
    try:
        report = json.loads(read_text(REPORT_PATH))
        entries = report.get("entries") or {}
        return entries if isinstance(entries, dict) else {}
    except Exception:
        return {}


def dart_escape(value: str) -> str:
    return (value or "").replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ").strip()


def write_registry(entries):
    lines = [
        "import 'spot_image_registry.dart';",
        "",
        "/// Türkiye genelindeki çekim noktaları için otomatik indirilen, açık lisanslı",
        "/// gerçek görseller. `tools/build_spot_image_catalog.py` tarafından üretilir.",
        "const spotImageAutoRegistry = <String, SpotImageInfo>{",
    ]
    for spot_id in sorted(entries):
        item = entries[spot_id]
        lines.extend([
            f"  '{dart_escape(spot_id)}': SpotImageInfo(",
            f"    assetPath: '{dart_escape(item.get('assetPath', ''))}',",
            f"    networkUrl: '{dart_escape(item.get('networkUrl', ''))}',",
            f"    sourceName: '{dart_escape(item.get('sourceName', 'Wikimedia Commons'))}',",
            f"    author: '{dart_escape(item.get('author', ''))}',",
            f"    license: '{dart_escape(item.get('license', ''))}',",
            f"    sourcePage: '{dart_escape(item.get('sourcePage', ''))}',",
            "  ),",
        ])
    lines.extend(["};", ""])
    AUTO_REGISTRY.write_text("\n".join(lines), encoding="utf-8")


def main():
    spots = collect_spots()
    manual = manual_ids()
    previous = load_previous_entries()
    entries = {}
    unresolved = []

    for index, spot in enumerate(spots, start=1):
        spot_id = spot["id"]
        if spot_id in manual:
            continue

        old = previous.get(spot_id)
        if isinstance(old, dict):
            asset = str(old.get("assetPath") or "")
            if asset and (ROOT / asset).exists():
                entries[spot_id] = old
                continue

        print(f"[{index}/{len(spots)}] {spot['city']} / {spot['name']}", flush=True)
        record = resolve_spot(spot)
        if not record:
            unresolved.append(spot)
            continue
        asset_path = download_image(record["networkUrl"], spot_id)
        if not asset_path:
            unresolved.append(spot)
            continue
        record["assetPath"] = asset_path
        record["spotName"] = spot["name"]
        record["city"] = spot["city"]
        entries[spot_id] = record
        time.sleep(0.08)

    write_registry(entries)
    report = {
        "totalSpotsDiscovered": len(spots),
        "manualRegistryCount": len([s for s in spots if s["id"] in manual]),
        "autoResolvedCount": len(entries),
        "unresolvedCount": len(unresolved),
        "entries": entries,
        "unresolved": unresolved,
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"Catalog complete: total={len(spots)} manual={report['manualRegistryCount']} "
        f"auto={len(entries)} unresolved={len(unresolved)}",
        flush=True,
    )
    if unresolved:
        print("Unresolved spots:")
        for item in unresolved:
            print(f" - {item['id']} | {item['city']} | {item['name']}")


if __name__ == "__main__":
    main()
