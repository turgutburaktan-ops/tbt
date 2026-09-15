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

class VenueLoadException implements Exception {
  const VenueLoadException(this.venues);
  final List<NearbyVenue> venues;
}

class NearbyVenueService {
  NearbyVenueService._()
    : _clientFactory = (() => http.Client()),
      _businessLoader = null;

  NearbyVenueService.forTesting({
    required http.Client Function() clientFactory,
    required Future<List<NearbyVenue>> Function(
      NearbyVenueCategory,
      double,
      double,
      int,
    )
    businessLoader,
  }) : _clientFactory = clientFactory,
       _businessLoader = businessLoader;

  final http.Client Function() _clientFactory;
  final Future<List<NearbyVenue>> Function(
    NearbyVenueCategory,
    double,
    double,
    int,
  )?
  _businessLoader;
  static final instance = NearbyVenueService._();
  static const _cacheLifetime = Duration(hours: 18);
  static const int cityScaleRadiusMeters = 80000;
  // Plate/ISO order, independent of the alphabetically sorted city picker.
  static const _provinceNames = <String>[
    'Adana',
    'Adıyaman',
    'Afyonkarahisar',
    'Ağrı',
    'Amasya',
    'Ankara',
    'Antalya',
    'Artvin',
    'Aydın',
    'Balıkesir',
    'Bilecik',
    'Bingöl',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Çanakkale',
    'Çankırı',
    'Çorum',
    'Denizli',
    'Diyarbakır',
    'Edirne',
    'Elazığ',
    'Erzincan',
    'Erzurum',
    'Eskişehir',
    'Gaziantep',
    'Giresun',
    'Gümüşhane',
    'Hakkâri',
    'Hatay',
    'Isparta',
    'Mersin',
    'İstanbul',
    'İzmir',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kırklareli',
    'Kırşehir',
    'Kocaeli',
    'Konya',
    'Kütahya',
    'Malatya',
    'Manisa',
    'Kahramanmaraş',
    'Mardin',
    'Muğla',
    'Muş',
    'Nevşehir',
    'Niğde',
    'Ordu',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Tekirdağ',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Şanlıurfa',
    'Uşak',
    'Van',
    'Yozgat',
    'Zonguldak',
    'Aksaray',
    'Bayburt',
    'Karaman',
    'Kırıkkale',
    'Batman',
    'Şırnak',
    'Bartın',
    'Ardahan',
    'Iğdır',
    'Yalova',
    'Karabük',
    'Kilis',
    'Osmaniye',
    'Düzce',
  ];

  String? _provinceCode(_VenueQueryState state) {
    if (!state.selectedCity) return null;
    final index = _provinceNames.indexWhere(
      (name) => _fold(name) == _fold(state.cityName ?? ''),
    );
    return index < 0 ? null : 'TR-${(index + 1).toString().padLeft(2, '0')}';
  }

  static const _endpoints = <String>[
    'https://overpass.kumi.systems/api/interpreter',
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
  final Map<String, Set<void Function(List<NearbyVenue>)>> _listeners = {};
  final Map<String, List<NearbyVenue>> _latestInFlight = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _businessSnapshot;
  DateTime? _businessSnapshotAt;
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _businessRequest;
  SharedPreferences? _preferences;
  Future<void> _osmQueue = Future.value();

  void _publish(String key, List<NearbyVenue> venues) {
    if (venues.isEmpty) return;
    _latestInFlight[key] = List<NearbyVenue>.of(venues);
    for (final listener in List.of(
      _listeners[key] ?? <void Function(List<NearbyVenue>)>{},
    )) {
      listener(List<NearbyVenue>.of(venues));
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _businessCatalog() {
    if (_businessSnapshot != null &&
        _businessSnapshotAt != null &&
        DateTime.now().difference(_businessSnapshotAt!) <
            const Duration(minutes: 5)) {
      return Future.value(_businessSnapshot!);
    }
    if (_businessRequest != null) return _businessRequest!;
    final request = () async {
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final query = FirebaseFirestore.instance
          .collection('business_venues')
          .where('source', isEqualTo: 'user_submission')
          .orderBy(FieldPath.documentId)
          .limit(500);
      while (true) {
        final page =
            await (docs.isEmpty ? query : query.startAfterDocument(docs.last))
                .get()
                .timeout(const Duration(seconds: 5));
        docs.addAll(page.docs);
        if (page.docs.length < 500) return docs;
      }
    }();
    _businessRequest = request;
    return request
        .then((snapshot) {
          _businessSnapshot = snapshot;
          _businessSnapshotAt = DateTime.now();
          return snapshot;
        })
        .whenComplete(() {
          _businessRequest = null;
        });
  }

  double? _cityLatitude, _cityLongitude, _south, _west, _north, _east;
  String? _cityName;
  int _cityRevision = 0;
  Future<void> _citySaveQueue = Future.value();
  static const _cityPreferenceKey = 'venue_selected_city_v1';

  Future<String?> restoreSelectedCity() async {
    if (_cityName != null) return _cityName;
    final revision = _cityRevision;
    final prefs = await _prefs();
    if (revision != _cityRevision) return _cityName;
    try {
      final raw = prefs.getString(_cityPreferenceKey);
      if (raw == null) return null;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final name = d['name'] as String;
      final lat = (d['latitude'] as num).toDouble();
      final lon = (d['longitude'] as num).toDouble();
      if (!_provinceNames.any((n) => _fold(n) == _fold(name)) ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180)
        return null;
      _cityName = name;
      _cityLatitude = lat;
      _cityLongitude = lon;
      _south = (d['south'] as num?)?.toDouble();
      _west = (d['west'] as num?)?.toDouble();
      _north = (d['north'] as num?)?.toDouble();
      _east = (d['east'] as num?)?.toDouble();
      return name;
    } catch (_) {
      return null;
    }
  }

  Future<void> flushSelectedCity() => _citySaveQueue;

  void _persistCity() {
    _cityRevision++;
    final snapshot = _cityName == null
        ? null
        : jsonEncode({
            'name': _cityName,
            'latitude': _cityLatitude,
            'longitude': _cityLongitude,
            'south': _south,
            'west': _west,
            'north': _north,
            'east': _east,
          });
    _citySaveQueue = _citySaveQueue
        .then((_) async {
          final prefs = await _prefs();
          if (snapshot == null) {
            await prefs.remove(_cityPreferenceKey);
          } else {
            await prefs.setString(_cityPreferenceKey, snapshot);
          }
        })
        .catchError((Object _) {
          /* Keep the current in-memory selection. */
        });
  }

  String? get selectedCityName => _cityName;
  bool get hasSelectedCity => _cityLatitude != null && _cityLongitude != null;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _fold(String v) => v
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('â', 'a')
      .replaceAll('i̇', 'i')
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
        name: _provinceNames.firstWhere(
          (name) => _fold(name) == f,
          orElse: () =>
              (address['province'] ?? address['city'] ?? address['town'] ?? q)
                  .toString(),
        ),
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
    _persistCity();
  }

  void useCurrentCity() {
    _cityName = null;
    _cityLatitude = null;
    _cityLongitude = null;
    _south = null;
    _west = null;
    _north = null;
    _east = null;
    _persistCity();
  }

  Future<List<NearbyVenue>> nearby({
    required NearbyVenueCategory category,
    required double latitude,
    required double longitude,
    int radiusMeters = cityScaleRadiusMeters,
    bool forceRefresh = false,
    bool useSelectedCity = true,
    bool reportIncomplete = false,
    void Function(List<NearbyVenue>)? onUpdate,
  }) {
    final state = useSelectedCity
        ? _snapshotState(latitude, longitude)
        : _VenueQueryState(
            cityName: null,
            latitude: latitude,
            longitude: longitude,
            south: null,
            west: null,
            north: null,
            east: null,
            selectedCity: false,
          );
    final key = _cacheKeyForState(category, state, radiusMeters);
    if (onUpdate != null) {
      (_listeners[key] ??= <void Function(List<NearbyVenue>)>{}).add(onUpdate);
    }
    final running = _inFlight[key];
    if (running != null) {
      final latest = _latestInFlight[key];
      if (onUpdate != null && latest != null)
        onUpdate(List<NearbyVenue>.of(latest));
      return _resultForCaller(running, reportIncomplete).whenComplete(() {
        _listeners[key]?.remove(onUpdate);
      });
    }

    final request = _nearbyInternal(
      category: category,
      state: state,
      radiusMeters: radiusMeters,
      forceRefresh: forceRefresh,
      key: key,
    );
    _inFlight[key] = request;
    return _resultForCaller(request, reportIncomplete).whenComplete(() {
      if (identical(_inFlight[key], request)) {
        _inFlight.remove(key);
        _listeners.remove(key);
        _latestInFlight.remove(key);
      }
    });
  }

  Future<List<NearbyVenue>> _resultForCaller(
    Future<List<NearbyVenue>> request,
    bool reportIncomplete,
  ) async {
    try {
      return await request;
    } on VenueLoadException catch (error) {
      if (!reportIncomplete && error.venues.isNotEmpty) return error.venues;
      rethrow;
    }
  }

  Future<List<NearbyVenue>> _nearbyInternal({
    required NearbyVenueCategory category,
    required _VenueQueryState state,
    required int radiusMeters,
    required bool forceRefresh,
    required String key,
  }) async {
    final p = await _prefs();
    final currentCache = _readCache(p, key);
    // Keep the last working narrow-area list during migration, but always
    // request the province list before considering it fully refreshed.
    final cached =
        currentCache ??
        _readCache(
          p,
          key.replaceFirst('city_venues_v10_province_', 'city_venues_v9_'),
        );
    var osm = cached?.venues ?? <NearbyVenue>[];
    var business = <NearbyVenue>[];
    var osmFailed = false;
    var businessFailed = false;
    // Paint disk results before either network source completes.
    _publish(key, osm);
    final businessFuture =
        _tbtBusinesses(
              category,
              state.latitude,
              state.longitude,
              radiusMeters,
              state,
            )
            .then((items) {
              business = items;
              _publish(key, _merge(osm, business));
            })
            .catchError((Object _) {
              businessFailed = true;
            });
    final osmFuture = () async {
      if (!forceRefresh && currentCache != null && !currentCache.isExpired)
        return;
      final fresh = await _fetchFreshOsm(
        category: category,
        state: state,
        radiusMeters: radiusMeters,
      );
      if (fresh == null) {
        osmFailed = true;
        return;
      }
      osm = fresh;
      _publish(key, _merge(osm, business));
      try {
        await p.setString(
          key,
          jsonEncode({
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'venues': fresh.map((v) => v.toJson()).toList(),
          }),
        );
      } catch (_) {}
    }();
    await Future.wait([businessFuture, osmFuture]);
    final result = _merge(osm, business);
    if (osmFailed || businessFailed) {
      throw VenueLoadException(result);
    }
    return result;
  }

  Future<List<NearbyVenue>?> _fetchFreshOsm({
    required NearbyVenueCategory category,
    required _VenueQueryState state,
    required int radiusMeters,
  }) async {
    final previous = _osmQueue;
    final done = Completer<void>();
    _osmQueue = done.future;
    await previous;
    try {
      return await _requestOsm(
        category: category,
        state: state,
        radiusMeters: radiusMeters,
      );
    } finally {
      done.complete();
    }
  }

  Future<List<NearbyVenue>?> _requestOsm({
    required NearbyVenueCategory category,
    required _VenueQueryState state,
    required int radiusMeters,
  }) async {
    for (final endpoint in _endpoints) {
      final client = _clientFactory();
      try {
        final r = await client
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
            .timeout(const Duration(seconds: 60));
        if (r.statusCode != 200) continue;
        final decoded = jsonDecode(r.body);
        if (decoded is! Map ||
            decoded['elements'] is! List ||
            decoded['remark'] != null)
          continue;
        if (_provinceCode(state) != null &&
            !(decoded['elements'] as List).any(
              (e) => e is Map && e['type'] == 'area',
            ))
          continue;
        return _parse(r.body, category, state);
      } catch (_) {
        // Try the fallback without discarding already displayed results.
      } finally {
        client.close();
      }
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
    // An explicit province field takes precedence over center distance.
    final expected = _fold(state.cityName ?? '');
    final tagged = _fold(cityTag);
    if (tagged == expected && expected.isNotEmpty) return true;
    if (_provinceNames.any((name) => _fold(name) == tagged)) return false;
    // Legacy entries without a province can only use the available bounds.
    // Street names are never interpreted as province names.
    return state.insideBounds(lat, lon);
  }

  Future<List<NearbyVenue>> _tbtBusinesses(
    NearbyVenueCategory c,
    double a,
    double o,
    int r,
    _VenueQueryState state,
  ) async {
    try {
      if (_businessLoader != null) return await _businessLoader(c, a, o, r);
      final snap = await _businessCatalog();
      final out = <NearbyVenue>[];
      for (final doc in snap) {
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
        final city = (d['province'] ?? d['city'] ?? '').toString();
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
        final boostUntil = d['boostActiveUntil'] is Timestamp
            ? (d['boostActiveUntil'] as Timestamp).toDate()
            : null;
        final sponsored =
            d['boostActive'] == true &&
            boostUntil != null &&
            boostUntil.isAfter(DateTime.now());
        final routeSettings = d['routeSettings'] is Map
            ? Map<String, dynamic>.from(d['routeSettings'] as Map)
            : const <String, dynamic>{};
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
            imageUrl:
                (d['coverImageUrl'] ??
                        d['imageUrl'] ??
                        d['photoUrl'] ??
                        d['logoUrl'] ??
                        '')
                    .toString(),
            description: (d['shortDescription'] ?? d['description'] ?? '')
                .toString(),
            sponsored: sponsored,
            routeRecommended: routeSettings['enabled'] == true,
          ),
        );
      }
      out.sort((a, b) {
        final sponsoredOrder = (b.sponsored ? 1 : 0).compareTo(
          a.sponsored ? 1 : 0,
        );
        if (sponsoredOrder != 0) return sponsoredOrder;
        return (b.routeRecommended ? 1 : 0).compareTo(
          a.routeRecommended ? 1 : 0,
        );
      });
      return out;
    } catch (_) {
      rethrow;
    }
  }

  List<NearbyVenue> _merge(List<NearbyVenue> b, List<NearbyVenue> m) {
    final out = <NearbyVenue>[], seen = <String>{};
    for (final v in [...m, ...b]) {
      final k =
          '${v.name.toLowerCase().trim()}_${v.latitude.toStringAsFixed(4)}_${v.longitude.toStringAsFixed(4)}';
      if (seen.add(k)) out.add(v);
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
    return 'city_venues_v10_province_${c.name}_${r}_${(state.latitude * 10).round()}_${(state.longitude * 10).round()}$city';
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
    final province = _provinceCode(state);
    final scope = province != null
        ? '(area.province)'
        : state.hasBounds
        ? '(${state.south!},${state.west!},${state.north!},${state.east!})'
        : '(around:$r,$a,$o)';
    final f = c.osmFilters.map((x) => 'nwr$scope$x["name"];').join('\n');
    final area = province == null
        ? ''
        : 'area["ISO3166-2"="$province"]["admin_level"="4"]->.province;\n.province out ids;\n';
    return '[out:json][timeout:45];\n$area(\n$f\n);\nout center tags;';
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
      if (_provinceCode(state) == null &&
          !_belongsToSelectedCity(
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
          description: (tags['description:tr'] ?? tags['description'] ?? '')
              .toString(),
        ),
      );
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
      selectedCity &&
      south != null &&
      west != null &&
      north != null &&
      east != null;

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
