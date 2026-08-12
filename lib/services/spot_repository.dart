import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_spot.dart';

/// Camera bağımsız çekim noktası veri katmanı.
///
/// Şu an Firestore + yerel demo fallback kullanır. İleride Google Places,
/// OpenStreetMap veya editoryal kaynaklar bu sınıfın arkasına yeni adapter
/// olarak eklenebilir; UI doğrudan sağlayıcıya bağımlı kalmaz.
class SpotRepository {
  SpotRepository._();

  static final SpotRepository instance = SpotRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String spotsCollection = 'photo_spots';
  static const String submissionsCollection = 'spot_submissions';

  /// Firestore hazır değilse uygulamayı bozmadan demo verisini döndürür.
  Future<List<PhotoSpot>> loadSpots({
    String? city,
    String? category,
    int limit = 200,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(spotsCollection)
          .where('status', isEqualTo: 'published');

      if (city != null && city.trim().isNotEmpty) {
        query = query.where('cityKey', isEqualTo: _key(city));
      }

      if (category != null && category.trim().isNotEmpty) {
        query = query.where('categoryKey', isEqualTo: _key(category));
      }

      final snapshot = await query.limit(limit).get();
      final remote = snapshot.docs
          .map(_fromDocument)
          .whereType<PhotoSpot>()
          .toList();

      if (remote.isNotEmpty) {
        remote.sort((a, b) => b.rating.compareTo(a.rating));
        return remote;
      }
    } catch (_) {
      // Offline, eksik index veya henüz boş Firestore koleksiyonu mevcut
      // uygulama deneyimini bozmasın.
    }

    return _filterLocal(
      demoSpots,
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

          if (remote.isEmpty) return List<PhotoSpot>.from(demoSpots);

          remote.sort((a, b) => b.rating.compareTo(a.rating));
          return remote;
        });
  }

  Future<List<PhotoSpot>> search(String input, {int limit = 80}) async {
    final query = _key(input);
    if (query.isEmpty) return loadSpots(limit: limit);

    final all = await loadSpots(limit: limit);
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

  /// Kullanıcı tarafından önerilen noktayı doğrudan yayınlamaz.
  /// Moderasyon kuyruğuna yazar; böylece spam ve yanlış koordinatlar canlı
  /// haritaya otomatik düşmez.
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

  /// Harici sağlayıcılardan gelecek kayıtların Firestore'a aktarılacağı ortak
  /// normalize şeması. API anahtarı veya sağlayıcı SDK'sı burada tutulmaz.
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
