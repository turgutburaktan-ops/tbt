import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RoadRouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RoadRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    final km = distanceMeters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes dk';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours sa' : '$hours sa $rest dk';
  }
}

class RoadRouteService {
  RoadRouteService._();
  static final instance = RoadRouteService._();

  final http.Client _client = http.Client();
  final Map<String, _CachedRoadRoute> _cache = {};
  final Map<String, Future<RoadRouteResult?>> _inFlight = {};
  int _requestGeneration = 0;

  static const Duration _cacheLifetime = Duration(minutes: 8);

  Future<RoadRouteResult?> drivingRoute(List<LatLng> waypoints) {
    if (waypoints.length < 2) return Future.value(null);
    final key = _routeKey(waypoints);

    final running = _inFlight[key];
    if (running != null) return running;

    final generation = ++_requestGeneration;
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) return Future.value(cached.value);

    final request = _loadRoute(waypoints, key, generation);
    _inFlight[key] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    });
  }

  Future<RoadRouteResult?> _loadRoute(
    List<LatLng> waypoints,
    String key,
    int generation,
  ) async {
    final coordinates = waypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coordinates'
      '?overview=full&geometries=geojson&steps=false',
    );

    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': 'TBT/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return _fallbackIfCurrent(key, generation);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return _fallbackIfCurrent(key, generation);
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinatesList = geometry?['coordinates'] as List<dynamic>?;
      if (coordinatesList == null || coordinatesList.length < 2) {
        return _fallbackIfCurrent(key, generation);
      }

      final points = <LatLng>[];
      for (final raw in coordinatesList) {
        if (raw is! List || raw.length < 2) continue;
        final lon = raw[0];
        final lat = raw[1];
        if (lat is! num || lon is! num) continue;
        points.add(LatLng(lat.toDouble(), lon.toDouble()));
      }
      if (points.length < 2) return _fallbackIfCurrent(key, generation);

      final result = RoadRouteResult(
        points: points,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
      );
      _cache[key] = _CachedRoadRoute(result, DateTime.now());
      _trimCache();

      // A newer destination was selected while this request was in flight.
      // Keep the result cached, but never let it overwrite the newer route UI.
      if (generation != _requestGeneration) return null;
      return result;
    } catch (_) {
      return _fallbackIfCurrent(key, generation);
    }
  }

  RoadRouteResult? _fallbackIfCurrent(String key, int generation) {
    if (generation != _requestGeneration) return null;
    return _cache[key]?.value;
  }

  String _routeKey(List<LatLng> waypoints) => waypoints
      .map(
        (point) =>
            '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}',
      )
      .join('|');

  void _trimCache() {
    if (_cache.length <= 40) return;
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));
    for (final entry in entries.take(_cache.length - 40)) {
      _cache.remove(entry.key);
    }
  }
}

class _CachedRoadRoute {
  final RoadRouteResult value;
  final DateTime savedAt;

  const _CachedRoadRoute(this.value, this.savedAt);

  bool get isExpired =>
      DateTime.now().difference(savedAt) > RoadRouteService._cacheLifetime;
}
