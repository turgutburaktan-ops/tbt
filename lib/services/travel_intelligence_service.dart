import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/photo_spot.dart';

class RouteIntelligence {
  final double distanceKm;
  final int travelMinutes;
  final String weatherSummary;

  const RouteIntelligence({
    required this.distanceKm,
    required this.travelMinutes,
    required this.weatherSummary,
  });
}

class TravelIntelligenceService {
  TravelIntelligenceService._();

  static final instance = TravelIntelligenceService._();

  Future<RouteIntelligence> analyze(
    List<PhotoSpot> stops, {
    required String transport,
  }) async {
    if (stops.isEmpty) {
      return const RouteIntelligence(
        distanceKm: 0,
        travelMinutes: 0,
        weatherSummary: '',
      );
    }
    final route = await _route(stops, transport);
    final weather = await _weather(stops.first);
    return RouteIntelligence(
      distanceKm: route.$1,
      travelMinutes: route.$2,
      weatherSummary: weather,
    );
  }

  Future<(double, int)> _route(
    List<PhotoSpot> stops,
    String transport,
  ) async {
    final fallbackDistance = _airDistance(stops) * 1.28;
    final speed = switch (transport) {
      'Yürüyüş' => 4.5,
      'Bisiklet' => 15.0,
      _ => 38.0,
    };
    final fallback = (
      fallbackDistance,
      (fallbackDistance / speed * 60).round(),
    );
    if (stops.length < 2 || transport != 'Araç') return fallback;
    try {
      final coordinates = stops
          .map((spot) => '${spot.longitude},${spot.latitude}')
          .join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordinates?overview=false&steps=false',
      );
      final response = await http
          .get(uri, headers: const {'User-Agent': 'TBT-mobile/0.1'})
          .timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return fallback;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) return fallback;
      final route = routes.first as Map<String, dynamic>;
      final meters = (route['distance'] as num?)?.toDouble() ?? 0;
      final seconds = (route['duration'] as num?)?.toDouble() ?? 0;
      if (meters <= 0 || seconds <= 0) return fallback;
      return (meters / 1000, (seconds / 60).round());
    } catch (_) {
      return fallback;
    }
  }

  double _airDistance(List<PhotoSpot> stops) {
    var total = 0.0;
    for (var i = 1; i < stops.length; i++) {
      total += _haversine(stops[i - 1], stops[i]);
    }
    return total;
  }

  double _haversine(PhotoSpot a, PhotoSpot b) {
    const radius = 6371.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(b.latitude - a.latitude);
    final dLng = radians(b.longitude - a.longitude);
    final lat1 = radians(a.latitude);
    final lat2 = radians(b.latitude);
    final value = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return radius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  Future<String> _weather(PhotoSpot spot) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': spot.latitude.toString(),
        'longitude': spot.longitude.toString(),
        'current': 'temperature_2m,precipitation,weather_code',
        'timezone': 'auto',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return '';
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) return '';
      final temperature = (current['temperature_2m'] as num?)?.round();
      final precipitation = (current['precipitation'] as num?)?.toDouble() ?? 0;
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final condition = _weatherLabel(code);
      return '${temperature ?? '-'}° • $condition${precipitation > 0 ? ' • Yağış ${precipitation.toStringAsFixed(1)} mm' : ''}';
    } catch (_) {
      return '';
    }
  }

  String _weatherLabel(int code) {
    if (code == 0) return 'Açık';
    if (code <= 3) return 'Parçalı bulutlu';
    if (code <= 48) return 'Sisli';
    if (code <= 67) return 'Yağmurlu';
    if (code <= 77) return 'Karlı';
    if (code <= 82) return 'Sağanak';
    return 'Fırtınalı';
  }

  int estimateBudget({
    required double distanceKm,
    required int stopCount,
    required String budget,
    required String transport,
    required int mealStops,
    required bool hotel,
  }) {
    final multiplier = switch (budget) {
      'Ekonomik' => .7,
      'Rahat' => 1.55,
      _ => 1.0,
    };
    final travel = switch (transport) {
      'Araç' => distanceKm * 4.2,
      'Bisiklet' => 0,
      _ => distanceKm * 1.1,
    };
    final entries = stopCount * 90;
    final meals = mealStops * 350;
    final stay = hotel ? 2200 : 0;
    return ((travel + entries + meals + stay) * multiplier).round();
  }
}
