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

  Future<RoadRouteResult?> drivingRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
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
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinatesList = geometry?['coordinates'] as List<dynamic>?;
      if (coordinatesList == null || coordinatesList.length < 2) return null;

      final points = coordinatesList
          .map((raw) {
            final pair = raw as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          })
          .toList(growable: false);

      return RoadRouteResult(
        points: points,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
