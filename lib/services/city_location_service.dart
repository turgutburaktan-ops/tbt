import 'dart:convert';

import 'package:http/http.dart' as http;

class CityLocation {
  final String name;
  final double latitude;
  final double longitude;

  const CityLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class CityLocationService {
  CityLocationService._();
  static final instance = CityLocationService._();

  final Map<String, CityLocation> _cache = <String, CityLocation>{};

  Future<CityLocation?> resolve(String city) async {
    final clean = city.trim();
    if (clean.isEmpty) return null;
    final cacheKey = clean.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$clean, Türkiye',
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'tr',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'TBT-mobile/0.1 (city selector)',
          'Accept-Language': 'tr,en;q=0.7',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isEmpty || list.first is! Map) return null;
      final data = Map<String, dynamic>.from(list.first as Map);
      final lat = double.tryParse((data['lat'] ?? '').toString());
      final lon = double.tryParse((data['lon'] ?? '').toString());
      if (lat == null || lon == null) return null;
      final address = Map<String, dynamic>.from(data['address'] as Map? ?? const {});
      final resolvedName = (address['province'] ??
              address['city'] ??
              address['town'] ??
              address['state'] ??
              clean)
          .toString()
          .trim();
      final result = CityLocation(
        name: resolvedName.isEmpty ? clean : resolvedName,
        latitude: lat,
        longitude: lon,
      );
      _cache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }
}
