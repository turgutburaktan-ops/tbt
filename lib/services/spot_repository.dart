import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/curated_photo_spots.dart';
import '../data/curated_photo_spots_extra.dart';
import '../data/curated_photo_spots_cities.dart';
import '../data/curated_photo_spots_regions.dart';
import '../data/curated_photo_spots_official_routes.dart';
import '../data/curated_photo_spots_official_bulk.dart';
import '../data/curated_photo_spots_verified_expansion.dart';
import '../data/curated_photo_spots_official_complete.dart';
import '../data/curated_photo_spots_nationwide_expansion_v2.dart';
import '../data/curated_photo_spots_nationwide_expansion_v3.dart';
import '../models/photo_spot.dart';
import 'nationwide_candidate_spot_resolver.dart';

enum SpotSort { rating, name }

class SpotDiscoveryQuery {
  final String text;
  final String? city;
  final String? category;
  final String? tag;
  final double minRating;
  final SpotSort sort;
  final int limit;

  const SpotDiscoveryQuery({
    this.text = '',
    this.city,
    this.category,
    this.tag,
    this.minRating = 0,
    this.sort = SpotSort.rating,
    this.limit = 2000,
  });
}

class SpotRepository {
  SpotRepository._();
  static final SpotRepository instance = SpotRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String spotsCollection = 'photo_spots';
  static const String submissionsCollection = 'spot_submissions';

  Future<List<PhotoSpot>> loadSpots({
    String? city,
    String? category,
    int limit = 2000,
  }) async {
    var remote = <PhotoSpot>[];
    try {
      final snapshot = await _firestore
          .collection(spotsCollection)
          .where('status', isEqualTo: 'published')
          .where('coordinateVerified', isEqualTo: true)
          .limit(limit)
          .get();
      remote = snapshot.docs.map(_fromDocument).whereType<PhotoSpot>().toList();
    } catch (_) {}

    final curated = _mergeWithCurated(remote);
    final nationwide = NationwideCandidateSpotResolver.mergeInto(curated);
    return _filterLocal(nationwide, city: city, category: category);
  }

  Future<List<PhotoSpot>> discover({
    SpotDiscoveryQuery query = const SpotDiscoveryQuery(),
  }) async {
    final all = await loadSpots(limit: query.limit);
    final textKey = _key(query.text);
    final cityKey = _key(query.city ?? '');
    final categoryKey = _key(query.category ?? '');
    final tagKey = _key(query.tag ?? '');

    final filtered = all.where((spot) {
      if (query.minRating > 0 && spot.rating < query.minRating) return false;
      if (cityKey.isNotEmpty && _key(spot.city) != cityKey) return false;
      if (categoryKey.isNotEmpty && _key(spot.category) != categoryKey) return false;
      if (tagKey.isNotEmpty &&
          !spot.tags.any((tag) => _key(tag).contains(tagKey))) {
        return false;
      }
      return textKey.isEmpty || _searchableText(spot).contains(textKey);
    }).toList();

    if (query.sort == SpotSort.name) {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else {
      filtered.sort((a, b) {
        final rating = b.rating.compareTo(a.rating);
        return rating != 0 ? rating : a.name.compareTo(b.name);
      });
    }
    return filtered;
  }

  Future<List<String>> availableCities({int limit = 2000}) async =>
      _distinct((await loadSpots(limit: limit)).map((s) => s.city));

  Future<List<String>> availableCategories({int limit = 2000}) async =>
      _distinct((await loadSpots(limit: limit)).map((s) => s.category));

  Stream<List<PhotoSpot>> watchPublishedSpots({int limit = 2000}) => _firestore
      .collection(spotsCollection)
      .where('status', isEqualTo: 'published')
      .where('coordinateVerified', isEqualTo: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) {
        final remote =
            snapshot.docs.map(_fromDocument).whereType<PhotoSpot>().toList();
        return NationwideCandidateSpotResolver.mergeInto(
          _mergeWithCurated(remote),
        );
      });

  Future<List<PhotoSpot>> search(String input, {int limit = 2000}) =>
      discover(query: SpotDiscoveryQuery(text: input, limit: limit));

  List<PhotoSpot> _mergeWithCurated(List<PhotoSpot> remote) {
    final byId = <String, PhotoSpot>{
      for (final spot in demoSpots) spot.id: spot,
      for (final spot in curatedPhotoSpots) spot.id: spot,
      for (final spot in curatedPhotoSpotsExtra) spot.id: spot,
      for (final spot in curatedPhotoSpotsCities) spot.id: spot,
      for (final spot in curatedPhotoSpotsRegions) spot.id: spot,
      for (final spot in curatedPhotoSpotsOfficialRoutes) spot.id: spot,
      for (final spot in curatedPhotoSpotsOfficialBulk) spot.id: spot,
      for (final spot in curatedPhotoSpotsVerifiedExpansion) spot.id: spot,
      for (final spot in curatedPhotoSpotsOfficialComplete) spot.id: spot,
      for (final spot in curatedPhotoSpotsNationwideExpansionV2) spot.id: spot,
      for (final spot in curatedPhotoSpotsNationwideExpansionV3) spot.id: spot,
    };
    for (final spot in remote) {
      byId[spot.id] = spot;
    }
    return byId.values.toList();
  }

  Future<String> submitCandidate({
    required String name,
    required String city,
    required double latitude,
    required double longitude,
    String category = 'Genel',
    String description = '',
    String bestTime = '',
    String angle = '',
    String recommendedLens = '24-70mm',
    List<String> tags = const [],
    String imageUrl = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Yeni çekim noktası önermek için giriş yapmalısın.');
    }
    if (name.trim().length < 3 || city.trim().length < 2) {
      throw Exception('Nokta adı ve şehir bilgisi eksik.');
    }
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw Exception('Geçersiz koordinat.');
    }

    final ref = _firestore.collection(submissionsCollection).doc();
    await ref.set({
      'id': ref.id,
      'name': name.trim(),
      'city': city.trim(),
      'cityKey': _key(city),
      'latitude': latitude,
      'longitude': longitude,
      'coordinateVerified': false,
      'imageVerified': false,
      'category': category.trim().isEmpty ? 'Genel' : category.trim(),
      'categoryKey': _key(category.trim().isEmpty ? 'Genel' : category),
      'description': description.trim(),
      'bestTime': bestTime.trim(),
      'angle': angle.trim(),
      'recommendedLens':
          recommendedLens.trim().isEmpty ? '24-70mm' : recommendedLens.trim(),
      'tags': tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'imageUrl': imageUrl.trim(),
      'submittedBy': user.uid,
      'submittedByEmail': user.email ?? '',
      'status': 'pending',
      'sourceType': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Map<String, dynamic> normalizeExternalSpot({
    required String externalId,
    required String source,
    required String name,
    required String city,
    required double latitude,
    required double longitude,
    String category = 'Genel',
    String description = '',
    String imageUrl = '',
    double rating = 0,
    List<String> tags = const [],
  }) =>
      {
        'externalId': externalId.trim(),
        'sourceType': source.trim(),
        'name': name.trim(),
        'city': city.trim(),
        'cityKey': _key(city),
        'latitude': latitude,
        'longitude': longitude,
        'coordinateVerified': false,
        'imageVerified': false,
        'category': category.trim().isEmpty ? 'Genel' : category.trim(),
        'categoryKey': _key(category.trim().isEmpty ? 'Genel' : category),
        'description': description.trim(),
        'imageUrl': imageUrl.trim(),
        'rating': rating.clamp(0, 5),
        'tags': tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'status': 'review',
        'updatedAt': FieldValue.serverTimestamp(),
      };

  PhotoSpot? _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null || data['coordinateVerified'] != true) return null;

    final latitude = _asDouble(data['latitude']);
    final longitude = _asDouble(data['longitude']);
    if (latitude == null || longitude == null) return null;

    final name = (data['name'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    if (name.isEmpty || city.isEmpty) return null;

    return PhotoSpot(
      id: (data['id'] ?? doc.id).toString(),
      name: name,
      city: city,
      latitude: latitude,
      longitude: longitude,
      rating: _asDouble(data['rating']) ?? 0,
      bestTime: (data['bestTime'] ?? 'Gün ışığına göre kontrol et').toString(),
      angle: (data['angle'] ?? 'Noktada farklı açılar dene').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      category: (data['category'] ?? 'Genel').toString(),
      description: (data['description'] ?? '').toString(),
      recommendedLens: (data['recommendedLens'] ?? '24-70mm').toString(),
      difficulty: (data['difficulty'] ?? 'Kolay').toString(),
      tags: _stringList(data['tags']),
    );
  }

  List<PhotoSpot> _filterLocal(
    List<PhotoSpot> items, {
    String? city,
    String? category,
  }) =>
      items
          .where((spot) =>
              (city == null ||
                  city.trim().isEmpty ||
                  _key(spot.city) == _key(city)) &&
              (category == null ||
                  category.trim().isEmpty ||
                  _key(spot.category) == _key(category)))
          .toList();

  static String _searchableText(PhotoSpot spot) => [
        spot.name,
        spot.city,
        spot.category,
        spot.description,
        spot.bestTime,
        spot.angle,
        spot.recommendedLens,
        spot.difficulty,
        ...spot.tags,
      ].map(_key).join(' ');

  static List<String> _distinct(Iterable<String> values) {
    final byKey = <String, String>{};
    for (final value in values) {
      if (value.trim().isNotEmpty) {
        byKey.putIfAbsent(_key(value), () => value.trim());
      }
    }
    return byKey.values.toList()..sort();
  }

  static double? _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

  static List<String> _stringList(dynamic value) => value is List
      ? value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
      : const [];

  static String _key(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}
