import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nearby_venue.dart';

class NearbyVenueService {
  NearbyVenueService._();

  static final instance = NearbyVenueService._();

  static const _cacheLifetime = Duration(hours: 18);
  static const _endpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _headers = <String, String>{
    'User-Agent': 'TBT-mobile/0.1 (nearby places)',
    'Accept': 'application/json',
  };

  Future<List<NearbyVenue>> nearby({
    required NearbyVenueCategory category,
    required double latitude,
    required double longitude,
    int radiusMeters = 25000,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(category, latitude, longitude);
    final cached = _readCache(prefs, cacheKey);
    if (!forceRefresh && cached != null && !cached.isExpired) return cached.venues;

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: _headers,
          body: {'data': _query(category, latitude, longitude, radiusMeters)},
        ).timeout(const Duration(seconds: 28));
        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }
        final venues = _parse(response.body, category);
        await prefs.setString(cacheKey, jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'venues': venues.map((venue) => venue.toJson()).toList(),
        }));
        return venues;
      } catch (error) {
        lastError = error;
      }
    }
    if (cached != null) return cached.venues;
    throw Exception('Mekan verisi alınamadı: ${lastError ?? 'bağlantı hatası'}');
  }

  String _cacheKey(NearbyVenueCategory category, double latitude, double longitude) {
    final latCell = (latitude * 40).round();
    final lonCell = (longitude * 40).round();
    return 'nearby_venues_v3_${category.name}_${latCell}_$lonCell';
  }

  _CachedVenues? _readCache(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch((decoded['savedAt'] as num?)?.toInt() ?? 0);
      final venues = (decoded['venues'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => NearbyVenue.fromJson(Map<String, dynamic>.from(item)))
          .where((venue) => venue.name.isNotEmpty)
          .toList();
      return _CachedVenues(savedAt: savedAt, venues: venues);
    } catch (_) {
      return null;
    }
  }

  String _query(NearbyVenueCategory category, double latitude, double longitude, int radiusMeters) {
    final filters = category.osmFilters
        .map((filter) => '  nwr(around:$radiusMeters,$latitude,$longitude)$filter["name"];')
        .join('\n');
    return '''
[out:json][timeout:24];
(
$filters
);
out center tags;
''';
  }

  List<NearbyVenue> _parse(String body, NearbyVenueCategory category) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];
    final venues = <NearbyVenue>[];
    final seen = <String>{};
    for (final raw in elements.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final tags = Map<String, dynamic>.from(item['tags'] as Map? ?? const <String, dynamic>{});
      final name = (tags['name:tr'] ?? tags['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final center = item['center'] as Map?;
      final latitude = (item['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble();
      final longitude = (item['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble();
      if (latitude == null || longitude == null) continue;
      final dedupeKey = '${name.toLowerCase()}_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
      if (!seen.add(dedupeKey)) continue;

      final street = (tags['addr:street'] ?? '').toString().trim();
      final number = (tags['addr:housenumber'] ?? '').toString().trim();
      final district = (tags['addr:district'] ?? tags['addr:suburb'] ?? '').toString().trim();
      final city = (tags['addr:city'] ?? '').toString().trim();
      final address = [
        [street, number].where((part) => part.isNotEmpty).join(' '),
        district,
        city,
      ].where((part) => part.isNotEmpty).join(', ');

      venues.add(NearbyVenue(
        id: '${item['type'] ?? 'node'}-${item['id'] ?? dedupeKey}',
        category: category,
        name: name,
        latitude: latitude,
        longitude: longitude,
        address: address,
        openingHours: (tags['opening_hours'] ?? '').toString(),
        phone: (tags['contact:phone'] ?? tags['phone'] ?? '').toString(),
        website: (tags['contact:website'] ?? tags['website'] ?? '').toString(),
      ));
      if (venues.length >= 300) break;
    }
    return venues;
  }
}

class _CachedVenues {
  final DateTime savedAt;
  final List<NearbyVenue> venues;
  const _CachedVenues({required this.savedAt, required this.venues});
  bool get isExpired => DateTime.now().difference(savedAt) > NearbyVenueService._cacheLifetime;
}
