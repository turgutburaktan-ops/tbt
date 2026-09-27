"""Merge Google's SKAdNetwork list into every generated iOS host.

Source: https://developers.google.com/admob/ios/quick-start (2026-09-25).
The checked-in list makes release builds deterministic and works offline.
"""
import json
import plistlib
from pathlib import Path


def configure(path=Path('ios/Runner/Info.plist')):
    path = Path(path)
    data = plistlib.loads(path.read_bytes())
    identifiers = json.loads(Path(__file__).with_name('admob_skadnetwork_ids.json').read_text())
    items = data.setdefault('SKAdNetworkItems', [])
    existing = {item.get('SKAdNetworkIdentifier') for item in items}
    for identifier in identifiers:
        if identifier not in existing:
            items.append({'SKAdNetworkIdentifier': identifier})
            existing.add(identifier)
    path.write_bytes(plistlib.dumps(data, sort_keys=False))


if __name__ == '__main__':
    configure()
