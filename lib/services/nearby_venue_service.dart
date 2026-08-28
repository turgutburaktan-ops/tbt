import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nearby_venue.dart';

class CityVenueArea {
  final String name;
  final double latitude, longitude, south, west, north, east;
  const CityVenueArea({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
}

class NearbyVenueService {
  NearbyVenueService._();
  static final instance = NearbyVenueService._();
  static const _cacheLifetime = Duration(hours: 18);
  static const int cityScaleRadiusMeters = 80000;
  static const int _selectedCityMaxDistanceMeters = 55000;
  static const _endpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _headers = <String, String>{
    'User-Agent': 'TBT-mobile/0.1 (city places)',
    'Accept': 'application/json',
  };
  static const _localCities = <String, (String, double, double)>{
    'adana': ('Adana', 37, 35.3213),
    'ankara': ('Ankara', 39.9334, 32.8597),
    'antalya': ('Antalya', 36.8969, 30.7133),
    'bursa': ('Bursa', 40.1885, 29.061),
    'diyarbakir': ('Diyarbakır', 37.9144, 40.2306),
    'elazig': ('Elazığ', 38.6748, 39.2225),
    'erzurum': ('Erzurum', 39.9043, 41.2679),
    'eskisehir': ('Eskişehir', 39.7667, 30.5256),
    'gaziantep': ('Gaziantep', 37.0662, 37.3833),
    'istanbul': ('İstanbul', 41.0082, 28.9784),
    'izmir': ('İzmir', 38.4237, 27.1428),
    'kayseri': ('Kayseri', 38.7225, 35.4875),
    'konya': ('Konya', 37.8746, 32.4932),
    'malatya': ('Malatya', 38.3552, 38.3095),
    'mersin': ('Mersin', 36.8121, 34.6415),
    'samsun': ('Samsun', 41.2867, 36.33),
    'sanliurfa': ('Şanlıurfa', 37.1674, 38.7955),
    'trabzon': ('Trabzon', 41.0015, 39.7178),
    'van': ('Van', 38.5012, 43.3729),
  };

  final Map<String, Future<List<NearbyVenue>>> _inFlight =
      <String, Future<List<NearbyVenue>>>{};
  SharedPreferences? _preferences;

  double? _cityLatitude, _cityLongitude, _south, _west, _north, _east;
  String? _cityName;

  String? get selectedCityName => _cityName;
  bool get hasSelectedCity => _cityLatitude != null && _cityLongitude != null;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _fold(String v) => v
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  CityVenueArea _area(String n, double a, double o) => CityVenueArea(
    name: n,
    latitude: a,
    longitude: o,
    south: a - .55,
    north: a + .55,
    west: o - .65,
    east: o + .65,
  );

  Future<CityVenueArea?> findCity(String value) async {
    final q = value.trim();
    if (q.length < 2) return null;
    final f = _fold(q);
    for (final e in _localCities.entries) {
      if (_fold(e.key).startsWith(f) || f.startsWith(_fold(e.key))) {
        final c = e.value;
        return _area(c.$1, c.$2, c.$3);
      }
    }
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$q, Türkiye',
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'tr',
        'addressdetails': '1',
      });
      final r = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return null;
      final raw = jsonDecode(r.body);
      if (raw is! List || raw.isEmpty) return null;
      Map<String, dynamic>? chosen;
      for (final item in raw.whereType<Map>()) {
        final d = Map<String, dynamic>.from(item),
            t = (d['type'] ?? '').toString(),
            a = (d['addresstype'] ?? '').toString();
        if (t == 'administrative' || a == 'city' || a == 'province') {
          chosen = d;
          break;
        }
      }
      chosen ??= Map<String, dynamic>.from(raw.first as Map);
      final lat = double.tryParse((chosen['lat'] ?? '').toString()),
          lon = double.tryParse((chosen['lon'] ?? '').toString()),
          bbox = (chosen['boundingbox'] as List?)
              ?.map((e) => double.tryParse(e.toString()))
              .toList();
      if (lat == null ||
          lon == null ||
          bbox == null ||
          bbox.length < 4 ||
          bbox.any((e) => e == null)) {
        return null;
      }
      final address = chosen['address'] is Map
          ? Map<String, dynamic>.from(chosen['address'] as Map)
          : const <String, dynamic>{};
      return CityVenueArea(
        name: (address['province'] ?? address['city'] ?? address['town'] ?? q)
            .toString(),
        latitude: lat,
        longitude: lon,
        south: bbox[0]!,
        north: bbox[1]!,
        west: bbox[2]!,
        east: bbox[3]!,
      );
    } catch (_) {
      return null;
    }
  }

  void selectCity({
    required String name,
    required double latitude,
    required double longitude,
    double? south,
    double? west,
    double? north,
    double? east,
  }) {
    _cityName = name.trim();
    _cityLatitude = latitude;
    _cityLongitude = longitude;
    _south = south;
    _west = west;
    _north = north;
    _east = east;
  }

  void useCurrentCity() {
    _cityName = null;
    _cityLatitude = null;
    _cityLongitude = null;
    _south = null;
    _west = null;
    _north = null;
    _east = null;
  }

  Future<List<NearbyVenue>> nearby({
    required NearbyVenueCategory category,
    required double latitude,
    required double longitude,
    int radiusMeters = cityScaleRadiusMeters,
    bool forceRefresh = false,
  }) {
    final state = _snapshotState(latitude, longitude);
    final key = _cacheKeyForState(category, state, radiusMeters);
    final running = _inFlight[key];
    if (running != null) return running;

    final request = _nearbyInternal(
      category: category,
      state: state,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
      key: key,
    );
    _inFlight[key] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    });
  }

  Future<List<NearbyVenue>> _nearbyInternal({
    required NearbyVenueCategory category,
    required _VenueQueryState state,
    required int radiusMeters,
    required bool forceRefresh,
    required String key,
  }) async {
    final p = await _prefs();
    final cached = _readCache(p, key);
    final businessFuture = _tbtBusinesses(
      category,
      state.latitude,
      state.longitude,
      radiusMeters,
      state,
    );

    // Stale-while-refresh behavior: normal navigation should never block on a
    // slow Overpass endpoint when we already have usable city data.
    if (!forceRefresh && cached != null) {
      final business = await businessFuture;
      final merged = _merge(cached.venues, business);
      if (cached.isExpired) {
        unawaited(
          _refreshCacheQuietly(
            category: category,
            state: state,
            radiusMeters: radiusMeters,
            key: key,
          ),
        );
      }
      return merged;
    }

    final fresh = await _fetchFreshOsm(
      category: category,
      state: state,
      radiusMeters: radiusMeters,
    );
    if (fresh != null) {
      try {
        await p.setString(
          key,
          jsonEncode({
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'venues': fresh.map((v) => v.toJson()).toList(),
          }),
        );
      } catch (_) {}
      return _merge(fresh, await businessFuture);
    }

    final t = await businessFuture;
    if (cached != null) return _merge(cached.venues, t);
    if (t.isNotEmpty) return t;
    throw Exception('Mekan verisi alınamadı.');
  }

  Future<void> _refreshCacheQuietly({
    required NearbyVenueCategory category,
    required _VenueQueryState state,
    required int radiusMeters,
    required String key,
  }) async {
    try {
      final fresh = await _fetchFreshOsm(
        category: category,
        state: state,
        radiusMeters: radiusMeters,
      );
      if (fresh == null) return;
      final p = await _prefs();
      await p.setString(
        key,
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'venues': fresh.map((v) => v.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  Future<List<NearbyVenue>?> _fetchFreshOsm({
    required NearbyVenueCategory category,
    required _VenueQueryState state,
    required int radiusMeters,
  }) async {
    for (final endpoint in _endpoints) {
      try {
        final r = await http
            .post(
              Uri.parse(endpoint),
              headers: _headers,
              body: {
                'data': _query(
                  category,
                  state.latitude,
                  state.longitude,
                  radiusMeters,
                  state,
                ),
              },
            )
            .timeout(const Duration(seconds: 7));
        if (r.statusCode != 200) continue;
        return _parse(r.body, category, state);
      } catch (_) {}
    }
    return null;
  }

  _VenueQueryState _snapshotState(double latitude, double longitude) {
    final selected = hasSelectedCity;
    return _VenueQueryState(
      cityName: _cityName,
      latitude: _cityLatitude ?? latitude,
      longitude: _cityLongitude ?? longitude,
      south: _south,
      west: _west,
      north: _north,
      east: _east,
      selectedCity: selected,
    );
  }

  bool _belongsToSelectedCity(
    _VenueQueryState state,
    double lat,
    double lon, {
    String cityTag = '',
    String address = '',
  }) {
    if (!state.selectedCity) return true;
    if (state.hasBounds && !state.insideBounds(lat, lon)) return false;
    if (_distanceMeters(state.latitude, state.longitude, lat, lon) >
        _selectedCityMaxDistanceMeters) {
      return false;
    }

    final expected = _fold(state.cityName ?? '');
    if (expected.isEmpty) return true;
    final tagged = _fold(cityTag);
    if (tagged.isNotEmpty &&
        !tagged.contains(expected) &&
        !expected.contains(tagged)) {
      return false;
    }
    final foldedAddress = _fold(address);
    if (foldedAddress.isNotEmpty) {
      const otherMajorCities = <String>[
        'diyarbakir',
        'malatya',
        'bingol',
        'tunceli',
        'erzincan',
        'adiyaman',
      ];
      for (final other in otherMajorCities) {
        if (other != expected && foldedAddress.contains(other)) return false;
      }
    }
    return true;
  }

  Future<List<NearbyVenue>> _tbtBusinesses(
    NearbyVenueCategory c,
    double a,
    double o,
    int r,
    _VenueQueryState state,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('business_venues')
          .where('source', isEqualTo: 'user_submission')
          .limit(500)
          .get()
          .timeout(const Duration(seconds: 5));
      final out = <NearbyVenue>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['verified'] != true ||
            d['pendingListing'] == true ||
            (d['category'] ?? '').toString() != c.name) {
          continue;
        }
        final lat = (d['latitude'] as num?)?.toDouble(),
            lon = (d['longitude'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        final address = (d['address'] ?? '').toString();
        final city = (d['city'] ?? d['province'] ?? '').toString();
        if (state.selectedCity) {
          if (!_belongsToSelectedCity(
            state,
            lat,
            lon,
            cityTag: city,
            address: address,
          )) {
            continue;
          }
        } else if (_distanceMeters(a, o, lat, lon) > r) {
          continue;
        }
        final n = (d['venueName'] ?? '').toString().trim();
        if (n.isEmpty) continue;
        out.add(
          NearbyVenue(
            id: (d['venueId'] ?? doc.id).toString(),
            category: c,
            name: n,
            latitude: lat,
            longitude: lon,
            address: address,
            openingHours: (d['openingHours'] ?? '').toString(),
            phone: (d['phone'] ?? '').toString(),
            website: (d['website'] ?? '').toString(),
            imageUrl: (
              d['coverImageUrl'] ??
              d['imageUrl'] ??
              d['photoUrl'] ??
              d['logoUrl'] ??
              ''
            ).toString(),
            description: (
              d['shortDescription'] ?? d['description'] ?? ''
            ).toString(),
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  List<NearbyVenue> _merge(List<NearbyVenue> b, List<NearbyVenue> m) {
    final out = <NearbyVenue>[], seen = <String>{};
    for (final v in [...m, ...b]) {
      final k =
          '${v.name.toLowerCase().trim()}_${v.latitude.toStringAsFixed(4)}_${v.longitude.toStringAsFixed(4)}';
      if (seen.add(k)) out.add(v);
      if (out.length >= 600) break;
    }
    return out;
  }

  double _distanceMeters(double a, double o, double b, double p) {
    const e = 6371000.0;
    double rad(double v) => v * math.pi / 180;
    final x = rad(b - a),
        y = rad(p - o),
        z =
            math.sin(x / 2) * math.sin(x / 2) +
            math.cos(rad(a)) *
                math.cos(rad(b)) *
                math.sin(y / 2) *
                math.sin(y / 2);
    return e * 2 * math.atan2(math.sqrt(z), math.sqrt(1 - z));
  }

  String _cacheKeyForState(
    NearbyVenueCategory c,
    _VenueQueryState state,
    int r,
  ) {
    final city = state.selectedCity
        ? '_${state.cityName?.toLowerCase().replaceAll(' ', '_') ?? 'city'}'
        : '_nearby';
    return 'city_venues_v8_${c.name}_${r}_${(state.latitude * 10).round()}_${(state.longitude * 10).round()}$city';
  }

  _CachedVenues? _readCache(SharedPreferences p, String key) {
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>,
          saved = DateTime.fromMillisecondsSinceEpoch(
            (d['savedAt'] as num?)?.toInt() ?? 0,
          ),
          venues = ((d['venues'] as List<dynamic>?) ?? const [])
              .whereType<Map>()
              .map((e) => NearbyVenue.fromJson(Map<String, dynamic>.from(e)))
              .where((v) => v.name.isNotEmpty)
              .toList();
      return _CachedVenues(savedAt: saved, venues: venues);
    } catch (_) {
      return null;
    }
  }

  String _query(
    NearbyVenueCategory c,
    double a,
    double o,
    int r,
    _VenueQueryState state,
  ) {
    final f = c.osmFilters
        .map(
          (x) => state.hasBounds
              ? '  nwr(${state.south!},${state.west!},${state.north!},${state.east!})$x["name"];'
              : '  nwr(around:$r,$a,$o)$x["name"];',
        )
        .join('\n');
    return '[out:json][timeout:10];\n(\n$f\n);\nout center tags;';
  }

  String _osmImageUrl(Map<String, dynamic> tags) {
    final direct = (tags['image'] ?? '').toString().trim();
    if (direct.startsWith('https://') || direct.startsWith('http://')) {
      return direct;
    }
    final commons = (tags['wikimedia_commons'] ?? '').toString().trim();
    if (commons.isEmpty) return '';
    final fileName = commons.toLowerCase().startsWith('file:')
        ? commons.substring(5).trim()
        : commons;
    if (fileName.isEmpty || commons.toLowerCase().startsWith('category:')) {
      return '';
    }
    return Uri.https(
      'commons.wikimedia.org',
      '/wiki/Special:FilePath/$fileName',
      {'width': '640'},
    ).toString();
  }

  List<NearbyVenue> _parse(
    String body,
    NearbyVenueCategory c,
    _VenueQueryState state,
  ) {
    final d = jsonDecode(body) as Map<String, dynamic>,
        elements = (d['elements'] as List<dynamic>?) ?? const [];
    final out = <NearbyVenue>[], seen = <String>{};
    for (final raw in elements.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw),
          tags = Map<String, dynamic>.from(
            (item['tags'] as Map?) ?? const <String, dynamic>{},
          ),
          n = (tags['name:tr'] ?? tags['name'] ?? '').toString().trim();
      if (n.isEmpty) continue;
      final center = item['center'] as Map?,
          a =
              (item['lat'] as num?)?.toDouble() ??
              (center?['lat'] as num?)?.toDouble(),
          o =
              (item['lon'] as num?)?.toDouble() ??
              (center?['lon'] as num?)?.toDouble();
      if (a == null || o == null) continue;
      final street = (tags['addr:street'] ?? '').toString().trim(),
          number = (tags['addr:housenumber'] ?? '').toString().trim(),
          district = (tags['addr:district'] ?? tags['addr:suburb'] ?? '')
              .toString()
              .trim(),
          city = (tags['addr:city'] ?? tags['addr:province'] ?? '')
              .toString()
              .trim(),
          address = [
            [street, number].where((x) => x.isNotEmpty).join(' '),
            district,
            city,
          ].where((x) => x.isNotEmpty).join(', ');
      if (!_belongsToSelectedCity(
        state,
        a,
        o,
        cityTag: city,
        address: address,
      )) {
        continue;
      }
      final k =
          '${n.toLowerCase()}_${a.toStringAsFixed(4)}_${o.toStringAsFixed(4)}';
      if (!seen.add(k)) continue;
      out.add(
        NearbyVenue(
          id: '${item['type'] ?? 'node'}-${item['id'] ?? k}',
          category: c,
          name: n,
          latitude: a,
          longitude: o,
          address: address,
          openingHours: (tags['opening_hours'] ?? '').toString(),
          phone: (tags['contact:phone'] ?? tags['phone'] ?? '').toString(),
          website: (tags['contact:website'] ?? tags['website'] ?? '')
              .toString(),
          imageUrl: _osmImageUrl(tags),
          description: (
            tags['description:tr'] ?? tags['description'] ?? ''
          ).toString(),
        ),
      );
      if (out.length >= 600) break;
    }
    return out;
  }
}

class _VenueQueryState {
  final String? cityName;
  final double latitude;
  final double longitude;
  final double? south;
  final double? west;
  final double? north;
  final double? east;
  final bool selectedCity;

  const _VenueQueryState({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.selectedCity,
  });

  bool get hasBounds =>
      selectedCity && south != null && west != null && north != null && east != null;

  bool insideBounds(double lat, double lon) =>
      !hasBounds ||
      (lat >= south! && lat <= north! && lon >= west! && lon <= east!);
}

class _CachedVenues {
  final DateTime savedAt;
  final List<NearbyVenue> venues;
  const _CachedVenues({required this.savedAt, required this.venues});
  bool get isExpired =>
      DateTime.now().difference(savedAt) > NearbyVenueService._cacheLifetime;
}
