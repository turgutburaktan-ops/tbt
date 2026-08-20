#!/usr/bin/env python3
"""Compatibility wrapper for the 1100-place catalog quality audit.

Some hand-curated Dart metadata uses double-quoted strings when an author name
contains an apostrophe. The original audit parser only accepted single quotes,
which produced a false missing-author error. This wrapper accepts both forms
without weakening any quality rule.
"""
from __future__ import annotations

import re

import audit_verified_spot_catalog as base


def string_field(body: str, name: str) -> str:
    single = re.search(rf"{name}:\s*'((?:\\'|[^'])*)'", body)
    if single:
        return single.group(1).replace("\\'", "'").strip()
    double = re.search(rf'{name}:\s*"((?:\\"|[^"])*)"', body)
    if double:
        return double.group(1).replace('\\"', '"').strip()
    return ''


base.sf = string_field

if __name__ == '__main__':
    raise SystemExit(base.main())
