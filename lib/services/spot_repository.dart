import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_spot.dart';
import 'nationwide_candidate_spot_resolver.dart';
import 'spot_quality_gate.dart';

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
  static const Duration _cacheLifetime = Duration(minutes: 5);

  List<PhotoSpot>? _cachedSafeSpots;
  DateTime? _cachedAt;
  Future<List<PhotoSpot>>? _loadInFlight;

  Future<List<PhotoSpot>> loadSpots({
    String? city,
    String? category,
    int limit = 2000,
  }) async {
    final cached = _cachedSafeSpots;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheLifetime) {
      return _filterLocal(cached, city: city, category: category);
    }

    final running = _loadInFlight;
    final all = running ?? _startLoad(limit);
    final result = await all;
    return _filterLocal(result, city: city, category: category);
  }

  Future<List<PhotoSpot>> _startLoad(int limit) {
    final request = _loadRemoteSafe(limit);
    _loadInFlight = request;
    return request.whenComplete(() {
      if (identical(_loadInFlight, request)) _loadInFlight = null;
    });
  }

  Future<List<PhotoSpot>> _loadRemoteSafe(int limit) async {
    var remote = <PhotoSpot>[];
    try {
      final snapshot = await _firestore
          .collection(spotsCollection)
          .where('status', isEqualTo: 'published')
          .where('coordinateVerified', isEqualTo: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 7));
      remote = snapshot.docs.map(_fromDocument).whereType<PhotoSpot>().toList();
    } catch (_) {
      final stale = _cachedSafeSpots;
      if (stale != null && stale.isNotEmpty) return stale;
    }

    final verified = NationwideCandidateSpotResolver.mergeInto(remote);
    final safe = SpotQualityGate.filterSafe(verified);
    _cachedSafeSpots = List<PhotoSpot>.unmodifiable(safe);
    _cachedAt = DateTime.now();
    return _cachedSafeSpots!;
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
      if (categoryKey.isNotEmpty && _key(spot.category) != categoryKey) {
        return false;
      }
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
        final remote = snapshot.docs
            .map(_fromDocument)
            .whereType<PhotoSpot>()
            .toList();
        final merged = NationwideCandidateSpotResolver.mergeInto(remote);
        final safe = SpotQualityGate.filterSafe(merged);
        _cachedSafeSpots = List<PhotoSpot>.unmodifiable(safe);
        _cachedAt = DateTime.now();
        return safe;
      });

  Future<List<PhotoSpot>> search(String input, {int limit = 2000}) => discover(
    query: SpotDiscoveryQuery(text: input, limit: limit),
  );

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
      throw Exception('Yeni gezilecek yer önermek için giriş yapmalısın.');
    }
    if (name.trim().length < 3 || city.trim().length < 2) {
      throw Exception('Yer adı ve şehir bilgisi eksik.');
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
      'recommendedLens': recommendedLens.trim().isEmpty
          ? '24-70mm'
          : recommendedLens.trim(),
      'tags': tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'imageUrl': imageUrl.trim(),
      'submittedBy': user.uid,
      'submittedByEmail': user.email ?? '',
      'status': 'pending',
      'sourceType': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
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
  }) => {
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
    if (data == null ||
        data['coordinateVerified'] != true ||
        data['imageVerified'] != true) {
      return null;
    }

    final latitude = _asDouble(data['latitude']);
    final longitude = _asDouble(data['longitude']);
    if (latitude == null || longitude == null) return null;

    final name = (data['name'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    if (name.isEmpty || city.isEmpty) return null;

    final sourceTags = _stringList(data['tags']);
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
      tags: <String>{'FirestoreDoğrulanmış', ...sourceTags}.toList(),
    );
  }

  List<PhotoSpot> _filterLocal(
    List<PhotoSpot> items, {
    String? city,
    String? category,
  }) => items
      .where(
        (spot) =>
            (city == null ||
                city.trim().isEmpty ||
                _key(spot.city) == _key(city)) &&
            (category == null ||
                category.trim().isEmpty ||
                _key(spot.category) == _key(category)),
      )
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

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  static List<String> _stringList(dynamic value) => value is List
      ? value
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
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
