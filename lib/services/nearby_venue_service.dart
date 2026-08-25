import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nearby_venue.dart';

class NearbyVenueService {
  NearbyVenueService._();
  static final instance = NearbyVenueService._();

  static const _cacheLifetime = Duration(hours: 18);
  // City-scale discovery: location is used for ordering, not for a tiny
  // "near me" cut-off. 80 km covers the full urban area and outskirts of
  // most Turkish cities while keeping Overpass requests bounded.
  static const int cityScaleRadiusMeters = 80000;
  static const _endpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _headers = <String, String>{
    'User-Agent': 'TBT-mobile/0.1 (city places)',
    'Accept': 'application/json',
  };

  Future<List<NearbyVenue>> nearby({
    required NearbyVenueCategory category,
    required double latitude,
    required double longitude,
    int radiusMeters = cityScaleRadiusMeters,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(category, latitude, longitude, radiusMeters);
    final cached = _readCache(prefs, cacheKey);
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return _merge(cached.venues, await _tbtBusinesses(category, latitude, longitude, radiusMeters));
    }

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
        final osm = _parse(response.body, category);
        await prefs.setString(cacheKey, jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'venues': osm.map((venue) => venue.toJson()).toList(),
        }));
        return _merge(osm, await _tbtBusinesses(category, latitude, longitude, radiusMeters));
      } catch (error) {
        lastError = error;
      }
    }

    final tbt = await _tbtBusinesses(category, latitude, longitude, radiusMeters);
    if (cached != null) return _merge(cached.venues, tbt);
    if (tbt.isNotEmpty) return tbt;
    throw Exception('Mekan verisi alınamadı: ${lastError ?? 'bağlantı hatası'}');
  }

  Future<List<NearbyVenue>> _tbtBusinesses(
    NearbyVenueCategory category,
    double latitude,
    double longitude,
    int radiusMeters,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('business_venues')
          .where('source', isEqualTo: 'user_submission')
          .limit(500)
          .get();
      final out = <NearbyVenue>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['verified'] != true ||
            d['pendingListing'] == true ||
            (d['category'] ?? '').toString() != category.name) continue;
        final lat = (d['latitude'] as num?)?.toDouble();
        final lon = (d['longitude'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        if (_distanceMeters(latitude, longitude, lat, lon) > radiusMeters) continue;
        final name = (d['venueName'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        out.add(NearbyVenue(
          id: (d['venueId'] ?? doc.id).toString(),
          category: category,
          name: name,
          latitude: lat,
          longitude: lon,
          address: (d['address'] ?? '').toString(),
          openingHours: (d['openingHours'] ?? '').toString(),
          phone: (d['phone'] ?? '').toString(),
          website: (d['website'] ?? '').toString(),
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  List<NearbyVenue> _merge(List<NearbyVenue> base, List<NearbyVenue> manual) {
    final out = <NearbyVenue>[];
    final seen = <String>{};
    for (final venue in [...manual, ...base]) {
      final key = '${venue.name.toLowerCase().trim()}_${venue.latitude.toStringAsFixed(4)}_${venue.longitude.toStringAsFixed(4)}';
      if (seen.add(key)) out.add(venue);
      if (out.length >= 600) break;
    }
    return out;
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earth = 6371000.0;
    double rad(double v) => v * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _cacheKey(
    NearbyVenueCategory category,
    double latitude,
    double longitude,
    int radiusMeters,
  ) {
    final latCell = (latitude * 10).round();
    final lonCell = (longitude * 10).round();
    return 'city_venues_v4_${category.name}_${radiusMeters}_${latCell}_$lonCell';
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
      final address = [[street, number].where((part) => part.isNotEmpty).join(' '), district, city]
          .where((part) => part.isNotEmpty)
          .join(', ');
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
      if (venues.length >= 500) break;
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
