import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteLeg {
  final double meters;
  final double seconds;
  const RouteLeg(this.meters, this.seconds);
  String get label =>
      '${(meters / 1000).toStringAsFixed(1)} km · ${(seconds / 60).ceil()} dk';
}

class RouteItinerary {
  final List<LatLng> points;
  final List<RouteLeg> legs;
  const RouteItinerary(this.points, this.legs);
  double get meters => legs.fold(0, (sum, leg) => sum + leg.meters);
  double get seconds => legs.fold(0, (sum, leg) => sum + leg.seconds);
}

/// Separate routing graphs are required: changing OSRM's URL profile alone
/// does not turn a driving server into a walking server.
class RouteItineraryService {
  RouteItineraryService({http.Client? client})
    : _client = client ?? http.Client();
  static final instance = RouteItineraryService();
  final http.Client _client;
  final _cache = <String, RouteItinerary>{};
  Future<void> _queue = Future.value();
  DateTime _lastRequest = DateTime(2000);

  Future<RouteItinerary?> calculate(List<LatLng> stops, String mode) {
    if (stops.length < 2 ||
        stops.length > 13 ||
        !['Araç', 'Yürüyüş', 'Bisiklet'].contains(mode))
      return Future.value(null);
    final coordinates = stops
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final key = '$mode:$coordinates';
    final result = _queue.then((_) async {
      if (_cache.containsKey(key)) return _cache[key];
      final wait =
          1100 - DateTime.now().difference(_lastRequest).inMilliseconds;
      if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      _lastRequest = DateTime.now();
      final graph = mode == 'Yürüyüş'
          ? 'foot'
          : mode == 'Bisiklet'
          ? 'bike'
          : 'car';
      try {
        final response = await _client
            .get(
              Uri.parse(
                'https://routing.openstreetmap.de/routed-$graph/route/v1/driving/$coordinates?overview=full&geometries=geojson&steps=false&radiuses=${List.filled(stops.length, '100').join(';')}',
              ),
              headers: {'User-Agent': 'TBT/1.0 route-planner'},
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return null;
        final value = decode(jsonDecode(response.body), stops.length);
        if (value != null) {
          if (_cache.length >= 30) _cache.remove(_cache.keys.first);
          _cache[key] = value;
        }
        return value;
      } catch (_) {
        return null;
      }
    });
    _queue = result.then<void>((_) {});
    return result;
  }

  static RouteItinerary? decode(dynamic data, int stopCount) {
    if (data is! Map || data['code'] != 'Ok') return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route = routes.first;
    if (route is! Map || route['legs'] is! List || route['geometry'] is! Map)
      return null;
    final rawLegs = route['legs'] as List;
    if (rawLegs.length != stopCount - 1) return null;
    final legs = <RouteLeg>[];
    for (final leg in rawLegs) {
      if (leg is! Map || leg['distance'] is! num || leg['duration'] is! num)
        return null;
      final meters = (leg['distance'] as num).toDouble();
      final seconds = (leg['duration'] as num).toDouble();
      if (!meters.isFinite || !seconds.isFinite || meters < 0 || seconds < 0)
        return null;
      legs.add(RouteLeg(meters, seconds));
    }
    final rawPoints = route['geometry']['coordinates'];
    if (rawPoints is! List || rawPoints.length < 2) return null;
    final points = <LatLng>[];
    for (final point in rawPoints) {
      if (point is! List ||
          point.length < 2 ||
          point[0] is! num ||
          point[1] is! num)
        return null;
      final lat = (point[1] as num).toDouble(),
          lon = (point[0] as num).toDouble();
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180)
        return null;
      points.add(LatLng(lat, lon));
    }
    return RouteItinerary(points, legs);
  }
}
