import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/curated_photo_spots.dart';
import '../models/photo_spot.dart';

/// Camera bağımsız çekim noktası veri katmanı.
///
/// Firestore kayıtlarını yerel kürasyon kataloğuyla birleştirir. Böylece
/// Firestore'da birkaç kayıt bulunması uygulamadaki hazır noktaları gizlemez.
/// İleride Google Places/OpenStreetMap gibi sağlayıcılar bu katmanın arkasına
/// adapter olarak eklenebilir.
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
    int limit = 200,
  }) async {
    var remote = <PhotoSpot>[];

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(spotsCollection)
          .where('status', isEqualTo: 'published');

      final snapshot = await query.limit(limit).get();
      remote = snapshot.docs
          .map(_fromDocument)
          .whereType<PhotoSpot>()
          .toList();
    } catch (_) {
      // Offline/izin/index problemi yerel kataloğu engellemesin.
    }

    final merged = _mergeWithCurated(remote);
    return _filterLocal(
      merged,
      city: city,
      category: category,
    );
  }

  Stream<List<PhotoSpot>> watchPublishedSpots({int limit = 200}) {
    return _firestore
        .collection(spotsCollection)
        .where('status', isEqualTo: 'published')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final remote = snapshot.docs
              .map(_fromDocument)
              .whereType<PhotoSpot>()
              .toList();
          return _mergeWithCurated(remote);
        });
  }

  Future<List<PhotoSpot>> search(String input, {int limit = 200}) async {
    final query = _key(input);
    final all = await loadSpots(limit: limit);
    if (query.isEmpty) return all;

    return all.where((spot) {
      final haystack = [
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
      return haystack.contains(query);
    }).toList();
  }

  List<PhotoSpot> _mergeWithCurated(List<PhotoSpot> remote) {
    // Demo + editoryal katalog aynı veri katmanından geçer. Böylece harita ve
    // repository kullanan keşfet yüzeyleri her zaman zengin bir katalog görür.
    // Aynı id varsa sıralama: demo < curated < Firestore published.
    final byId = <String, PhotoSpot>{
      for (final spot in demoSpots) spot.id: spot,
      for (final spot in curatedPhotoSpots) spot.id: spot,
    };

    // Firestore aynı id'yi yayınladıysa güncel remote kayıt üstün gelir.
    for (final spot in remote) {
      byId[spot.id] = spot;
    }

    final result = byId.values.toList();
    result.sort((a, b) {
      final ratingOrder = b.rating.compareTo(a.rating);
      if (ratingOrder != 0) return ratingOrder;
      return a.name.compareTo(b.name);
    });
    return result;
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

    if (latitude < -90 || latitude > 90 ||
        longitude < -180 || longitude > 180) {
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
  }) {
    return {
      'externalId': externalId.trim(),
      'sourceType': source.trim(),
      'name': name.trim(),
      'city': city.trim(),
      'cityKey': _key(city),
      'latitude': latitude,
      'longitude': longitude,
      'category': category.trim().isEmpty ? 'Genel' : category.trim(),
      'categoryKey': _key(category.trim().isEmpty ? 'Genel' : category),
      'description': description.trim(),
      'imageUrl': imageUrl.trim(),
      'rating': rating.clamp(0, 5),
      'tags': tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'status': 'review',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PhotoSpot? _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;

    final lat = _asDouble(data['latitude']);
    final lng = _asDouble(data['longitude']);
    if (lat == null || lng == null) return null;

    final name = (data['name'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    if (name.isEmpty || city.isEmpty) return null;

    return PhotoSpot(
      id: (data['id'] ?? doc.id).toString(),
      name: name,
      city: city,
      latitude: lat,
      longitude: lng,
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
  }) {
    return items.where((spot) {
      final cityOk = city == null || city.trim().isEmpty ||
          _key(spot.city) == _key(city);
      final categoryOk = category == null || category.trim().isEmpty ||
          _key(spot.category) == _key(category);
      return cityOk && categoryOk;
    }).toList();
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _key(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }
}
