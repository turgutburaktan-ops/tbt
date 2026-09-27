#!/usr/bin/env python3
"""Strict wrapper for the source-verified 1100-place generator.

The base generator already requires direct Wikidata P625 + P18 and Commons
license/resolution checks. This wrapper makes spatial deduplication stricter:
we do not publish two catalog cards within 18 metres of each other, even when
Wikidata models them as separate objects with different labels.
"""
from __future__ import annotations

import generate_verified_spot_catalog as base


def strict_duplicate(item: dict, accepted: list[dict], existing: list[dict]) -> bool:
    name_key = base.norm(item['name'])
    city_key = base.norm(item['city'])
    for other in [*existing, *accepted]:
        other_name = other.get('name_key', '')
        other_city = other.get('city_key', '')
        if name_key == other_name and (
            not city_key or not other_city or city_key == other_city
        ):
            return True
        # Travel catalog rule: one discoverable pin per physical micro-location.
        # This prevents cases such as Assos/Athena Temple, Kultepe/Nesa and
        # multiple Efes terrace-house Wikidata objects from stacking together.
        if base.distance_m(item, other) < 18:
            return True
    return False


base.duplicate = strict_duplicate

if __name__ == '__main__':
    raise SystemExit(base.main())
