from pathlib import Path

path = Path('lib/screens/route_planner_screen.dart')
text = path.read_text(encoding='utf-8')

# 1) Sort all candidates and selected stops by current-user distance after location is read.
old = """      setState(() {\n        _currentPosition = position;\n        _useCurrentLocation = true;\n      });\n"""
new = """      setState(() {\n        _currentPosition = position;\n        _useCurrentLocation = true;\n        _allSpots = _sortedFromCurrentPosition(_allSpots, position);\n        _stops\n          ..sort((a, b) => _distanceFromPosition(position, a)\n              .compareTo(_distanceFromPosition(position, b)));\n      });\n"""
if old not in text:
    raise SystemExit('location setState anchor not found')
text = text.replace(old, new, 1)

# 2) Add helpers before _message.
anchor = """  void _message(String text) {\n"""
helpers = """  double _distanceFromPosition(Position position, PhotoSpot spot) =>\n      Geolocator.distanceBetween(\n        position.latitude,\n        position.longitude,\n        spot.latitude,\n        spot.longitude,\n      );\n\n  List<PhotoSpot> _sortedFromCurrentPosition(\n    Iterable<PhotoSpot> spots,\n    Position position,\n  ) {\n    final sorted = spots.toList();\n    sorted.sort((a, b) => _distanceFromPosition(position, a)\n        .compareTo(_distanceFromPosition(position, b)));\n    return sorted;\n  }\n\n  double? _distanceToMeKm(PhotoSpot spot) {\n    final current = _currentPosition;\n    if (current == null) return null;\n    return _distanceFromPosition(current, spot) / 1000;\n  }\n\n  List<PhotoSpot> get _nearbyMapSpots {\n    final selectedIds = _stops.map((spot) => spot.id).toSet();\n    final candidates = _allSpots\n        .where((spot) => !selectedIds.contains(spot.id))\n        .toList();\n    final current = _currentPosition;\n    if (current != null) {\n      candidates.sort((a, b) => _distanceFromPosition(current, a)\n          .compareTo(_distanceFromPosition(current, b)));\n    }\n    return candidates.take(60).toList();\n  }\n\n  Future<void> _addSpotFromMap(PhotoSpot spot) async {\n    if (_stops.any((item) => item.id == spot.id)) return;\n    setState(() {\n      _stops.add(spot);\n      final current = _currentPosition;\n      if (current != null) {\n        _stops.sort((a, b) => _distanceFromPosition(current, a)\n            .compareTo(_distanceFromPosition(current, b)));\n      }\n    });\n    await Future<void>.delayed(const Duration(milliseconds: 70));\n    await _fitRoute();\n    _message('${spot.name} rotaya eklendi.');\n  }\n\n  void _message(String text) {\n"""
if anchor not in text:
    raise SystemExit('message anchor not found')
text = text.replace(anchor, helpers, 1)

# 3) Add unselected nearby pins before selected route pins.
anchor = """    for (var i = 0; i < _stops.length; i++) {\n"""
insert = """    for (final spot in _nearbyMapSpots) {\n      final km = _distanceToMeKm(spot);\n      markers.add(\n        Marker(\n          markerId: MarkerId('nearby_${spot.id}'),\n          position: LatLng(spot.latitude, spot.longitude),\n          icon: BitmapDescriptor.defaultMarkerWithHue(\n            BitmapDescriptor.hueViolet,\n          ),\n          infoWindow: InfoWindow(\n            title: spot.name,\n            snippet: km == null\n                ? '${spot.city} • Rotaya eklemek için pine dokun'\n                : '${spot.city} • ${km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0)} km • Dokun ve rotaya ekle',\n          ),\n          onTap: () => _addSpotFromMap(spot),\n        ),\n      );\n    }\n\n    for (var i = 0; i < _stops.length; i++) {\n"""
if anchor not in text:
    raise SystemExit('marker anchor not found')
text = text.replace(anchor, insert, 1)

# 4) Make picker results nearest-first and expose distance.
old = """          final matches = _allSpots\n              .where((spot) {\n                if (excluded.contains(spot.id)) return false;\n                if (key.isEmpty) return true;\n                final haystack = _normalize(\n                  '${spot.name} ${spot.city} ${spot.category} ${spot.tags.join(' ')}',\n                );\n                return haystack.contains(key);\n              })\n              .take(80)\n              .toList();\n"""
new = """          var matches = _allSpots\n              .where((spot) {\n                if (excluded.contains(spot.id)) return false;\n                if (key.isEmpty) return true;\n                final haystack = _normalize(\n                  '${spot.name} ${spot.city} ${spot.category} ${spot.tags.join(' ')}',\n                );\n                return haystack.contains(key);\n              })\n              .toList();\n          final current = _currentPosition;\n          if (current != null) {\n            matches = _sortedFromCurrentPosition(matches, current);\n          }\n          matches = matches.take(80).toList();\n"""
if old not in text:
    raise SystemExit('picker matches anchor not found')
text = text.replace(old, new, 1)

old = """                              subtitle: Text(\n                                '${spot.city} • ${spot.category} • ★ ${spot.rating}',\n                                maxLines: 1,\n                                overflow: TextOverflow.ellipsis,\n                              ),\n"""
new = """                              subtitle: Builder(\n                                builder: (_) {\n                                  final km = _distanceToMeKm(spot);\n                                  final distanceLabel = km == null\n                                      ? ''\n                                      : ' • ${km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0)} km';\n                                  return Text(\n                                    '${spot.city} • ${spot.category}$distanceLabel • ★ ${spot.rating}',\n                                    maxLines: 1,\n                                    overflow: TextOverflow.ellipsis,\n                                  );\n                                },\n                              ),\n"""
if old not in text:
    raise SystemExit('picker subtitle anchor not found')
text = text.replace(old, new, 1)

# 5) Adding from picker should keep nearest-first priority automatically.
old = """    if (selected == null || !mounted) return;\n    setState(() => _stops.add(selected));\n"""
new = """    if (selected == null || !mounted) return;\n    setState(() {\n      _stops.add(selected);\n      final current = _currentPosition;\n      if (current != null) {\n        _stops.sort((a, b) => _distanceFromPosition(current, a)\n            .compareTo(_distanceFromPosition(current, b)));\n      }\n    });\n"""
if old not in text:
    raise SystemExit('picker add anchor not found')
text = text.replace(old, new, 1)

# 6) Show distance in selected-stop list too.
old = """                              subtitle: Text(\n                                '${spot.city} • ${spot.bestTime}',\n                                maxLines: 1,\n                                overflow: TextOverflow.ellipsis,\n                                style: const TextStyle(color: Colors.white54),\n                              ),\n"""
new = """                              subtitle: Builder(\n                                builder: (_) {\n                                  final km = _distanceToMeKm(spot);\n                                  final distanceLabel = km == null\n                                      ? ''\n                                      : ' • ${km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0)} km';\n                                  return Text(\n                                    '${spot.city}$distanceLabel • ${spot.bestTime}',\n                                    maxLines: 1,\n                                    overflow: TextOverflow.ellipsis,\n                                    style: const TextStyle(color: Colors.white54),\n                                  );\n                                },\n                              ),\n"""
if old not in text:
    raise SystemExit('selected subtitle anchor not found')
text = text.replace(old, new, 1)

# 7) With no stops, center map on user and nearby points instead of showing only Turkey.
old = """    final controller = _mapController;\n    final points = _routePoints;\n    if (controller == null || points.isEmpty) return;\n"""
new = """    final controller = _mapController;\n    var points = _routePoints;\n    if (controller == null) return;\n    if (points.isEmpty && _currentPosition != null) {\n      final current = _currentPosition!;\n      points = [\n        LatLng(current.latitude, current.longitude),\n        ..._nearbyMapSpots.take(12).map(\n              (spot) => LatLng(spot.latitude, spot.longitude),\n            ),\n      ];\n    }\n    if (points.isEmpty) return;\n"""
if old not in text:
    raise SystemExit('fit route anchor not found')
text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('route planner patched: nearby map pins + nearest-first ordering')
