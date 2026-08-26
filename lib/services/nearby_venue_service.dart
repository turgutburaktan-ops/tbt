import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nearby_venue.dart';

class CityVenueArea {
  final String name;
  final double latitude;
  final double longitude;
  final double south;
  final double west;
  final double north;
  final double east;

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
  static const _endpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];
  static const _headers = <String, String>{
    'User-Agent': 'TBT-mobile/0.1 (city places)',
    'Accept': 'application/json',
  };

  double? _cityLatitude;
  double? _cityLongitude;
  double? _south;
  double? _west;
  double? _north;
  double? _east;
  String? _cityName;

  String? get selectedCityName => _cityName;
  bool get hasSelectedCity => _cityLatitude != null && _cityLongitude != null;

  Future<CityVenueArea?> findCity(String value) async {
    final query = value.trim();
    if (query.length < 2) return null;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$query, Türkiye',
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'tr',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final raw = jsonDecode(response.body);
      if (raw is! List || raw.isEmpty) return null;
      Map<String, dynamic>? chosen;
      for (final item in raw.whereType<Map>()) {
        final data = Map<String, dynamic>.from(item);
        final type = (data['type'] ?? '').toString();
        final addresstype = (data['addresstype'] ?? '').toString();
        if (type == 'administrative' || addresstype == 'city' || addresstype == 'province') {
          chosen = data;
          break;
        }
      }
      chosen ??= Map<String, dynamic>.from(raw.first as Map);
      final lat = double.tryParse((chosen['lat'] ?? '').toString());
      final lon = double.tryParse((chosen['lon'] ?? '').toString());
      final bbox = (chosen['boundingbox'] as List?)?.map((e) => double.tryParse(e.toString())).toList();
      if (lat == null || lon == null || bbox == null || bbox.length < 4 || bbox.any((e) => e == null)) return null;
      final display = (chosen['display_name'] ?? query).toString();
      final address = chosen['address'] is Map ? Map<String, dynamic>.from(chosen['address'] as Map) : const <String, dynamic>{};
      final cleanName = (address['province'] ?? address['city'] ?? address['town'] ?? query).toString();
      return CityVenueArea(
        name: cleanName.isEmpty ? display.split(',').first.trim() : cleanName,
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
  }) async {
    final queryLatitude = _cityLatitude ?? latitude;
    final queryLongitude = _cityLongitude ?? longitude;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(category, queryLatitude, queryLongitude, radiusMeters);
    final cached = _readCache(prefs, cacheKey);
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return _merge(cached.venues, await _tbtBusinesses(category, queryLatitude, queryLongitude, radiusMeters));
    }

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: _headers,
          body: {'data': _query(category, queryLatitude, queryLongitude, radiusMeters)},
        ).timeout(const Duration(seconds: 32));
        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }
        final osm = _parse(response.body, category);
        await prefs.setString(cacheKey, jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'venues': osm.map((venue) => venue.toJson()).toList(),
        }));
        return _merge(osm, await _tbtBusinesses(category, queryLatitude, queryLongitude, radiusMeters));
      } catch (error) {
        lastError = error;
      }
    }

    final tbt = await _tbtBusinesses(category, queryLatitude, queryLongitude, radiusMeters);
    if (cached != null) return _merge(cached.venues, tbt);
    if (tbt.isNotEmpty) return tbt;
    throw Exception('Mekan verisi alınamadı: ${lastError ?? 'bağlantı hatası'}');
  }

  Future<List<NearbyVenue>> _tbtBusinesses(NearbyVenueCategory category,double latitude,double longitude,int radiusMeters) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('business_venues').where('source', isEqualTo: 'user_submission').limit(500).get();
      final out = <NearbyVenue>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['verified'] != true || d['pendingListing'] == true || (d['category'] ?? '').toString() != category.name) continue;
        final lat = (d['latitude'] as num?)?.toDouble();
        final lon = (d['longitude'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        if (hasSelectedCity && _hasBounds) {
          if (!_insideBounds(lat, lon)) continue;
        } else if (_distanceMeters(latitude, longitude, lat, lon) > radiusMeters) {
          continue;
        }
        final name = (d['venueName'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        out.add(NearbyVenue(id:(d['venueId']??doc.id).toString(),category:category,name:name,latitude:lat,longitude:lon,address:(d['address']??'').toString(),openingHours:(d['openingHours']??'').toString(),phone:(d['phone']??'').toString(),website:(d['website']??'').toString()));
      }
      return out;
    } catch (_) { return const []; }
  }

  bool get _hasBounds => _south != null && _west != null && _north != null && _east != null;
  bool _insideBounds(double lat,double lon)=>!_hasBounds||(lat>=_south!&&lat<=_north!&&lon>=_west!&&lon<=_east!);

  List<NearbyVenue> _merge(List<NearbyVenue> base,List<NearbyVenue> manual) {
    final out=<NearbyVenue>[]; final seen=<String>{};
    for(final venue in [...manual,...base]){
      final key='${venue.name.toLowerCase().trim()}_${venue.latitude.toStringAsFixed(4)}_${venue.longitude.toStringAsFixed(4)}';
      if(seen.add(key))out.add(venue); if(out.length>=600)break;
    }
    return out;
  }

  double _distanceMeters(double lat1,double lon1,double lat2,double lon2){
    const earth=6371000.0; double rad(double v)=>v*math.pi/180.0; final dLat=rad(lat2-lat1),dLon=rad(lon2-lon1);
    final a=math.sin(dLat/2)*math.sin(dLat/2)+math.cos(rad(lat1))*math.cos(rad(lat2))*math.sin(dLon/2)*math.sin(dLon/2);
    return earth*2*math.atan2(math.sqrt(a),math.sqrt(1-a));
  }

  String _cacheKey(NearbyVenueCategory category,double latitude,double longitude,int radiusMeters){
    final latCell=(latitude*10).round(),lonCell=(longitude*10).round();
    final cityPart=hasSelectedCity?'_${_cityName?.toLowerCase().replaceAll(' ','_')??'city'}':'_nearby';
    return 'city_venues_v6_${category.name}_${radiusMeters}_${latCell}_${lonCell}$cityPart';
  }

  _CachedVenues? _readCache(SharedPreferences prefs,String key){
    final raw=prefs.getString(key); if(raw==null||raw.isEmpty)return null;
    try{
      final decoded=jsonDecode(raw) as Map<String,dynamic>; final savedAt=DateTime.fromMillisecondsSinceEpoch((decoded['savedAt'] as num?)?.toInt()??0);
      final venues=(decoded['venues'] as List<dynamic>???const[]).whereType<Map>().map((item)=>NearbyVenue.fromJson(Map<String,dynamic>.from(item))).where((venue)=>venue.name.isNotEmpty).toList();
      return _CachedVenues(savedAt:savedAt,venues:venues);
    }catch(_){return null;}
  }

  String _query(NearbyVenueCategory category,double latitude,double longitude,int radiusMeters){
    final filters=category.osmFilters.map((filter){
      if(hasSelectedCity&&_hasBounds){return '  nwr(${_south!},${_west!},${_north!},${_east!})$filter["name"];';}
      return '  nwr(around:$radiusMeters,$latitude,$longitude)$filter["name"];';
    }).join('\n');
    return '''
[out:json][timeout:28];
(
$filters
);
out center tags;
''';
  }

  List<NearbyVenue> _parse(String body,NearbyVenueCategory category){
    final decoded=jsonDecode(body) as Map<String,dynamic>; final elements=decoded['elements'] as List<dynamic>???const[]; final venues=<NearbyVenue>[]; final seen=<String>{};
    for(final raw in elements.whereType<Map>()){
      final item=Map<String,dynamic>.from(raw); final tags=Map<String,dynamic>.from(item['tags'] as Map???const<String,dynamic>{});
      final name=(tags['name:tr']??tags['name']??'').toString().trim(); if(name.isEmpty)continue;
      final center=item['center'] as Map?; final latitude=(item['lat'] as num?)?.toDouble()??(center?['lat'] as num?)?.toDouble(); final longitude=(item['lon'] as num?)?.toDouble()??(center?['lon'] as num?)?.toDouble();
      if(latitude==null||longitude==null)continue; if(hasSelectedCity&&_hasBounds&&!_insideBounds(latitude,longitude))continue;
      final dedupeKey='${name.toLowerCase()}_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}'; if(!seen.add(dedupeKey))continue;
      final street=(tags['addr:street']??'').toString().trim(),number=(tags['addr:housenumber']??'').toString().trim(),district=(tags['addr:district']??tags['addr:suburb']??'').toString().trim(),city=(tags['addr:city']??'').toString().trim();
      final address=[[street,number].where((part)=>part.isNotEmpty).join(' '),district,city].where((part)=>part.isNotEmpty).join(', ');
      venues.add(NearbyVenue(id:'${item['type']??'node'}-${item['id']??dedupeKey}',category:category,name:name,latitude:latitude,longitude:longitude,address:address,openingHours:(tags['opening_hours']??'').toString(),phone:(tags['contact:phone']??tags['phone']??'').toString(),website:(tags['contact:website']??tags['website']??'').toString()));
      if(venues.length>=600)break;
    }
    return venues;
  }
}

class _CachedVenues {
  final DateTime savedAt; final List<NearbyVenue> venues;
  const _CachedVenues({required this.savedAt,required this.venues});
  bool get isExpired=>DateTime.now().difference(savedAt)>NearbyVenueService._cacheLifetime;
}
