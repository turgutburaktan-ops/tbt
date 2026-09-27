#!/usr/bin/env python3
"""Run the nationwide licensed image catalog with Wikimedia-safe networking.

The original catalog logic stays in build_spot_image_catalog.py. This wrapper
supplies a descriptive contact User-Agent plus retry/backoff for Wikimedia API
requests, which is required for reliable unattended GitHub Actions runs.
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request

import build_spot_image_catalog as catalog

CONTACT_USER_AGENT = (
    "BestPhotoSpot/1.0 "
    "(https://github.com/turgutburaktan-ops/tbt; contact: turgutburaktan@gmail.com)"
)

catalog.USER_AGENT = CONTACT_USER_AGENT


def reliable_api_json(host: str, params: dict, timeout: int = 20):
    query = urllib.parse.urlencode(params)
    url = f"https://{host}/w/api.php?{query}"
    last_error: Exception | None = None

    for attempt in range(4):
        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": CONTACT_USER_AGENT,
                "Accept": "application/json",
                "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.7",
                "Referer": "https://github.com/turgutburaktan-ops/tbt",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status} from {host}")
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code not in {429, 500, 502, 503, 504}:
                print(f"API {host} rejected request with HTTP {exc.code}")
                return None
            retry_after = exc.headers.get("Retry-After") if exc.headers else None
            wait = int(retry_after) if retry_after and retry_after.isdigit() else (2 + attempt * 3)
            time.sleep(wait)
        except Exception as exc:
            last_error = exc
            if attempt == 3:
                break
            time.sleep(1.5 + attempt * 2)

    if last_error is not None:
        print(f"API request failed for {host}: {last_error}")
    return None


catalog.api_json = reliable_api_json

if __name__ == "__main__":
    catalog.main()
