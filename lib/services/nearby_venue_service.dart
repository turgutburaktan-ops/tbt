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
  const CityVenueArea({required this.name, required this.latitude, required this.longitude, required this.south, required this.west, required this.north, required this.east});
}

class NearbyVenueService {
  NearbyVenueService._();
  static final instance = NearbyVenueService._();
  static const _cacheLifetime = Duration(hours: 18);
  static const int cityScaleRadiusMeters = 80000;
  static const _endpoints = <String>['https://overpass-api.de/api/interpreter','https://overpass.private.coffee/api/interpreter'];
  static const _headers = <String,String>{'User-Agent':'TBT-mobile/0.1 (city places)','Accept':'application/json'};
  static const _localCities = <String,(String,double,double)> {
    'adana': ('Adana',37.0000,35.3213),'ankara':('Ankara',39.9334,32.8597),'antalya':('Antalya',36.8969,30.7133),
    'bursa':('Bursa',40.1885,29.0610),'diyarbakir':('Diyarbakır',37.9144,40.2306),'diyarbakır':('Diyarbakır',37.9144,40.2306),
    'elazig':('Elazığ',38.6748,39.2225),'elazığ':('Elazığ',38.6748,39.2225),'erzurum':('Erzurum',39.9043,41.2679),
    'eskisehir':('Eskişehir',39.7667,30.5256),'eskişehir':('Eskişehir',39.7667,30.5256),'gaziantep':('Gaziantep',37.0662,37.3833),
    'istanbul':('İstanbul',41.0082,28.9784),'i̇stanbul':('İstanbul',41.0082,28.9784),'izmir':('İzmir',38.4237,27.1428),'i̇zmir':('İzmir',38.4237,27.1428),
    'kayseri':('Kayseri',38.7225,35.4875),'konya':('Konya',37.8746,32.4932),'malatya':('Malatya',38.3552,38.3095),
    'mersin':('Mersin',36.8121,34.6415),'samsun':('Samsun',41.2867,36.3300),'sanliurfa':('Şanlıurfa',37.1674,38.7955),'şanlıurfa':('Şanlıurfa',37.1674,38.7955),
    'trabzon':('Trabzon',41.0015,39.7178),'van':('Van',38.5012,43.3729)
  };
  double? _cityLatitude,_cityLongitude,_south,_west,_north,_east; String? _cityName;
  String? get selectedCityName=>_cityName; bool get hasSelectedCity=>_cityLatitude!=null&&_cityLongitude!=null;
  String _fold(String v)=>v.trim().toLowerCase().replaceAll('ı','i').replaceAll('ğ','g').replaceAll('ü','u').replaceAll('ş','s').replaceAll('ö','o').replaceAll('ç','c');
  CityVenueArea _area(String name,double lat,double lon)=>CityVenueArea(name:name,latitude:lat,longitude:lon,south:lat-.65,north:lat+.65,west:lon-.8,east:lon+.8);

  Future<CityVenueArea?> findCity(String value) async {
    final query=value.trim(); if(query.length<2)return null;
    final folded=_fold(query);
    for(final entry in _localCities.entries){if(_fold(entry.key).startsWith(folded)||folded.startsWith(_fold(entry.key))){final c=entry.value;return _area(c.$1,c.$2,c.$3);}}
    try{
      final uri=Uri.https('nominatim.openstreetmap.org','/search',{'q':'$query, Türkiye','format':'jsonv2','limit':'5','countrycodes':'tr','addressdetails':'1'});
      final response=await http.get(uri,headers:_headers).timeout(const Duration(seconds:6)); if(response.statusCode!=200)return null;
      final raw=jsonDecode(response.body); if(raw is! List||raw.isEmpty)return null; Map<String,dynamic>? chosen;
      for(final item in raw.whereType<Map>()){final data=Map<String,dynamic>.from(item);final type=(data['type']??'').toString();final a=(data['addresstype']??'').toString();if(type=='administrative'||a=='city'||a=='province'){chosen=data;break;}}
      chosen??=Map<String,dynamic>.from(raw.first as Map); final lat=double.tryParse((chosen['lat']??'').toString()),lon=double.tryParse((chosen['lon']??'').toString());
      final bbox=(chosen['boundingbox'] as List?)?.map((e)=>double.tryParse(e.toString())).toList(); if(lat==null||lon==null||bbox==null||bbox.length<4||bbox.any((e)=>e==null))return null;
      final address=chosen['address'] is Map?Map<String,dynamic>.from(chosen['address'] as Map):const <String,dynamic>{}; final clean=(address['province']??address['city']??address['town']??query).toString();
      return CityVenueArea(name:clean,latitude:lat,longitude:lon,south:bbox[0]!,north:bbox[1]!,west:bbox[2]!,east:bbox[3]!);
    }catch(_){return null;}
  }
  void selectCity({required String name,required double latitude,required double longitude,double? south,double? west,double? north,double? east}){_cityName=name.trim();_cityLatitude=latitude;_cityLongitude=longitude;_south=south;_west=west;_north=north;_east=east;}
  void useCurrentCity(){_cityName=null;_cityLatitude=null;_cityLongitude=null;_south=null;_west=null;_north=null;_east=null;}
  Future<List<NearbyVenue>> nearby({required NearbyVenueCategory category,required double latitude,required double longitude,int radiusMeters=cityScaleRadiusMeters,bool forceRefresh=false}) async{
    final qLat=_cityLatitude??latitude,qLon=_cityLongitude??longitude;final prefs=await SharedPreferences.getInstance();final key=_cacheKey(category,qLat,qLon,radiusMeters);final cached=_readCache(prefs,key);
    if(!forceRefresh&&cached!=null&&!cached.isExpired)return _merge(cached.venues,await _tbtBusinesses(category,qLat,qLon,radiusMeters)); Object? lastError;
    for(final endpoint in _endpoints){try{final response=await http.post(Uri.parse(endpoint),headers:_headers,body:{'data':_query(category,qLat,qLon,radiusMeters)}).timeout(const Duration(seconds:20));if(response.statusCode!=200){lastError='HTTP ${response.statusCode}';continue;}final osm=_parse(response.body,category);await prefs.setString(key,jsonEncode({'savedAt':DateTime.now().millisecondsSinceEpoch,'venues':osm.map((v)=>v.toJson()).toList()}));return _merge(osm,await _tbtBusinesses(category,qLat,qLon,radiusMeters));}catch(e){lastError=e;}}
    final tbt=await _tbtBusinesses(category,qLat,qLon,radiusMeters);if(cached!=null)return _merge(cached.venues,tbt);if(tbt.isNotEmpty)return tbt;throw Exception('Mekan verisi alınamadı: ${lastError??'bağlantı hatası'}');
  }
  Future<List<NearbyVenue>> _tbtBusinesses(NearbyVenueCategory category,double latitude,double longitude,int radiusMeters) async{try{final snap=await FirebaseFirestore.instance.collection('business_venues').where('source',isEqualTo:'user_submission').limit(500).get();final out=<NearbyVenue>[];for(final doc in snap.docs){final d=doc.data();if(d['verified']!=true||d['pendingListing']==true||(d['category']??'').toString()!=category.name)continue;final lat=(d['latitude'] as num?)?.toDouble(),lon=(d['longitude'] as num?)?.toDouble();if(lat==null||lon==null)continue;if(hasSelectedCity&&_hasBounds){if(!_insideBounds(lat,lon))continue;}else if(_distanceMeters(latitude,longitude,lat,lon)>radiusMeters)continue;final name=(d['venueName']??'').toString().trim();if(name.isEmpty)continue;out.add(NearbyVenue(id:(d['venueId']??doc.id).toString(),category:category,name:name,latitude:lat,longitude:lon,address:(d['address']??'').toString(),openingHours:(d['openingHours']??'').toString(),phone:(d['phone']??'').toString(),website:(d['website']??'').toString()));}return out;}catch(_){return const [];}}
  bool get _hasBounds=>_south!=null&&_west!=null&&_north!=null&&_east!=null;bool _insideBounds(double lat,double lon)=>!_hasBounds||(lat>=_south!&&lat<=_north!&&lon>=_west!&&lon<=_east!);
  List<NearbyVenue> _merge(List<NearbyVenue> base,List<NearbyVenue> manual){final out=<NearbyVenue>[],seen=<String>{};for(final v in [...manual,...base]){final k='${v.name.toLowerCase().trim()}_${v.latitude.toStringAsFixed(4)}_${v.longitude.toStringAsFixed(4)}';if(seen.add(k))out.add(v);if(out.length>=600)break;}return out;}
  double _distanceMeters(double a,double b,double c,double d){const earth=6371000.0;double rad(double v)=>v*math.pi/180;final x=rad(c-a),y=rad(d-b);final z=math.sin(x/2)*math.sin(x/2)+math.cos(rad(a))*math.cos(rad(c))*math.sin(y/2)*math.sin(y/2);return earth*2*math.atan2(math.sqrt(z),math.sqrt(1-z));}
  String _cacheKey(NearbyVenueCategory c,double lat,double lon,int r){final city=hasSelectedCity?'_${_cityName?.toLowerCase().replaceAll(' ','_')??'city'}':'_nearby';return 'city_venues_v6_${c.name}_${r}_${(lat*10).round()}_${(lon*10).round()}$city';}
  _CachedVenues? _readCache(SharedPreferences p,String key){final raw=p.getString(key);if(raw==null||raw.isEmpty)return null;try{final d=jsonDecode(raw) as Map<String,dynamic>;final saved=DateTime.fromMillisecondsSinceEpoch((d['savedAt'] as num?)?.toInt()??0);final venues=(d['venues'] as List<dynamic>???const []).whereType<Map>().map((e)=>NearbyVenue.fromJson(Map<String,dynamic>.from(e))).where((v)=>v.name.isNotEmpty).toList();return _CachedVenues(savedAt:saved,venues:venues);}catch(_){return null;}}
  String _query(NearbyVenueCategory c,double lat,double lon,int r){final f=c.osmFilters.map((x)=>hasSelectedCity&&_hasBounds?'  nwr(${_south!},${_west!},${_north!},${_east!})$x["name"];':'  nwr(around:$r,$lat,$lon)$x["name"];').join('\n');return '[out:json][timeout:20];\n(\n$f\n);\nout center tags;';}
  List<NearbyVenue> _parse(String body,NearbyVenueCategory category){final d=jsonDecode(body) as Map<String,dynamic>;final elements=d['elements'] as List<dynamic>???const [];final out=<NearbyVenue>[],seen=<String>{};for(final raw in elements.whereType<Map>()){final item=Map<String,dynamic>.from(raw),tags=Map<String,dynamic>.from(item['tags'] as Map???const <String,dynamic>{});final name=(tags['name:tr']??tags['name']??'').toString().trim();if(name.isEmpty)continue;final center=item['center'] as Map?;final lat=(item['lat'] as num?)?.toDouble()??(center?['lat'] as num?)?.toDouble(),lon=(item['lon'] as num?)?.toDouble()??(center?['lon'] as num?)?.toDouble();if(lat==null||lon==null)continue;if(hasSelectedCity&&_hasBounds&&!_insideBounds(lat,lon))continue;final k='${name.toLowerCase()}_${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';if(!seen.add(k))continue;final street=(tags['addr:street']??'').toString().trim(),number=(tags['addr:housenumber']??'').toString().trim(),district=(tags['addr:district']??tags['addr:suburb']??'').toString().trim(),city=(tags['addr:city']??'').toString().trim();final address=[[street,number].where((x)=>x.isNotEmpty).join(' '),district,city].where((x)=>x.isNotEmpty).join(', ');out.add(NearbyVenue(id:'${item['type']??'node'}-${item['id']??k}',category:category,name:name,latitude:lat,longitude:lon,address:address,openingHours:(tags['opening_hours']??'').toString(),phone:(tags['contact:phone']??tags['phone']??'').toString(),website:(tags['contact:website']??tags['website']??'').toString()));if(out.length>=600)break;}return out;}
}
class _CachedVenues{final DateTime savedAt;final List<NearbyVenue> venues;const _CachedVenues({required this.savedAt,required this.venues});bool get isExpired=>DateTime.now().difference(savedAt)>NearbyVenueService._cacheLifetime;}
