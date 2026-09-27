import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'route_geometry.dart';

class TerrainSample {
  const TerrainSample(this.point, this.meters, this.elevation);
  final LatLng point;
  final double meters, elevation;
}

class RouteTerrain {
  RouteTerrain(List<TerrainSample> samples)
    : samples = List.unmodifiable(samples);
  final List<TerrainSample> samples;
  double get meters => samples.last.meters;
  // A 3 m deadband suppresses DEM noise without discarding gradual climbs.
  (double, double) get gainLoss {
    var anchor = samples.first.elevation, up = 0.0, down = 0.0;
    for (var i = 1; i < samples.length; i++) {
      final delta = samples[i].elevation - anchor;
      if (delta.abs() >= 3 || i == samples.length - 1) {
        if (delta > 0) {
          up += delta;
        } else {
          down -= delta;
        }
        anchor = samples[i].elevation;
      }
    }
    return (up, down);
  }

  double get maxGrade {
    var result = 0.0;
    var start = samples.first;
    for (final end in samples.skip(1)) {
      final run = end.meters - start.meters;
      if (run < 90) continue;
      result = math.max(
        result,
        (end.elevation - start.elevation).abs() / run * 100,
      );
      start = end;
    }
    return result;
  }

  /// Product heuristics, not an official trail grade. Terrain surface/technical
  /// obstacles are unavailable from OSRM, so the UI always labels this estimated.
  String difficulty(String mode) {
    final walking = mode == 'Yürüyüş';
    final km = meters / 1000, gain = gainLoss.$1;
    if (km >= (walking ? 15 : 50) ||
        gain >= (walking ? 700 : 1000) ||
        maxGrade >= (walking ? 20 : 12))
      return 'Zor';
    if (km >= (walking ? 6 : 20) ||
        gain >= (walking ? 200 : 350) ||
        maxGrade >= (walking ? 10 : 6))
      return 'Orta';
    return 'Kolay';
  }

  String reason(String mode) =>
      '${(meters / 1000).toStringAsFixed(1)} km, yaklaşık ${gainLoss.$1.round()} m tırmanış '
      've örneklenen en dik bölümde %${maxGrade.round()} eğim birlikte değerlendirildi. '
      '${mode == 'Yürüyüş' ? 'Yürüyüş' : 'Bisiklet'} eşikleri kullanıldı. '
      'Zemin ve teknik geçiş bilgisi bulunmadığından bu derece tahminidir.';
}

class RouteTerrainService {
  RouteTerrainService({
    http.Client? client,
    this.requestInterval = const Duration(milliseconds: 1100),
  }) : _client = client ?? http.Client();
  static final instance = RouteTerrainService();
  final http.Client _client;
  final Duration requestInterval;
  final _cache = <String, RouteTerrain>{};
  final _pending = <String, Future<RouteTerrain?>>{};
  Future<void> _queue = Future.value();
  DateTime _last = DateTime(2000);
  static bool supports(String mode) => mode == 'Yürüyüş' || mode == 'Bisiklet';

  /// Resample along every segment of the actual route, never between stops.
  /// At most 100 points per public API call, approximately 90 m spacing on
  /// shorter routes. Long routes are intentionally labelled estimates.
  static List<(LatLng, double)> samplePath(List<LatLng> path) {
    if (path.length < 2 ||
        path.any(
          (p) =>
              !p.latitude.isFinite ||
              !p.longitude.isFinite ||
              p.latitude.abs() > 90 ||
              p.longitude.abs() > 180,
        ))
      return [];
    final distances = <double>[0];
    for (var i = 1; i < path.length; i++) {
      distances.add(
        distances.last + RouteGeometry.distance(path[i - 1], path[i]),
      );
    }
    final total = distances.last;
    if (total < 1) return [];
    final count = (total / 90).ceil().clamp(1, 99) + 1;
    final result = <(LatLng, double)>[];
    var segment = 1;
    for (var i = 0; i < count; i++) {
      final target = total * i / (count - 1);
      while (segment < path.length - 1 && distances[segment] < target) {
        segment++;
      }
      final length = distances[segment] - distances[segment - 1];
      final t = length == 0 ? 0.0 : (target - distances[segment - 1]) / length;
      final a = path[segment - 1], b = path[segment];
      result.add((
        LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ),
        target,
      ));
    }
    return result;
  }

  Future<RouteTerrain?> load(List<LatLng> path, String mode) {
    if (!supports(mode)) return Future.value(null);
    final samples = samplePath(path);
    if (samples.length < 2) return Future.value(null);
    final locations = samples
        .map(
          (s) =>
              '${s.$1.latitude.toStringAsFixed(6)},${s.$1.longitude.toStringAsFixed(6)}',
        )
        .join('|');
    // Distances are part of the cache key, even when rounded coordinates match.
    final key = '$locations:${samples.last.$2}';
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    if (_pending.containsKey(key)) return _pending[key]!;
    final future = _queue.then((_) async {
      final wait = requestInterval - DateTime.now().difference(_last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _last = DateTime.now();
      try {
        final response = await _client
            .get(
              Uri.https('api.opentopodata.org', '/v1/srtm90m', {
                'locations': locations,
                'interpolation': 'bilinear',
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return null;
        final terrain = decode(jsonDecode(response.body), samples);
        if (terrain != null) {
          if (_cache.length >= 30) _cache.remove(_cache.keys.first);
          _cache[key] = terrain;
        }
        return terrain;
      } catch (_) {
        return null;
      }
    });
    _pending[key] = future;
    _queue = future.then<void>((_) {
      _pending.remove(key);
    });
    return future;
  }

  static RouteTerrain? decode(dynamic data, List<(LatLng, double)> samples) {
    if (samples.length < 2 || data is! Map || data['status'] != 'OK')
      return null;
    final rows = data['results'];
    if (rows is! List || rows.length != samples.length) return null;
    final result = <TerrainSample>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map || row['elevation'] is! num || row['location'] is! Map)
        return null;
      final elevation = (row['elevation'] as num).toDouble();
      final lat = row['location']['lat'], lng = row['location']['lng'];
      if (!elevation.isFinite ||
          elevation < -500 ||
          elevation > 9000 ||
          lat is! num ||
          lng is! num ||
          !lat.isFinite ||
          !lng.isFinite ||
          (lat.toDouble() - samples[i].$1.latitude).abs() > .0001 ||
          (lng.toDouble() - samples[i].$1.longitude).abs() > .0001)
        return null;
      result.add(TerrainSample(samples[i].$1, samples[i].$2, elevation));
    }
    return RouteTerrain(result);
  }
}
