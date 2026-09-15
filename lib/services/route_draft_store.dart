import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_spot.dart';

class RouteDraftStore {
  static String key(String uid) => 'route-wizard-v1:$uid';
  static Future<Map<String, dynamic>?> read(String uid) async {
    final raw = (await SharedPreferences.getInstance()).getString(key(uid));
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String uid, Map<String, dynamic> draft) async {
    await (await SharedPreferences.getInstance()).setString(
      key(uid),
      jsonEncode(draft),
    );
  }

  static Future<void> clear(String uid) async {
    await (await SharedPreferences.getInstance()).remove(key(uid));
  }

  static Map<String, dynamic> encodeSpot(PhotoSpot s) => {
    'id': s.id,
    'name': s.name,
    'city': s.city,
    'latitude': s.latitude,
    'longitude': s.longitude,
    'rating': s.rating,
    'bestTime': s.bestTime,
    'angle': s.angle,
    'imageUrl': s.imageUrl,
    'imageOriginalUrl': s.imageOriginalUrl,
    'imageSourcePage': s.imageSourcePage,
    'imageAuthor': s.imageAuthor,
    'imageLicense': s.imageLicense,
    'category': s.category,
    'description': s.description,
    'recommendedLens': s.recommendedLens,
    'difficulty': s.difficulty,
    'tags': s.tags,
  };
  static PhotoSpot decodeSpot(Map<String, dynamic> s) => PhotoSpot(
    id: s['id'] as String,
    name: s['name'] as String,
    city: s['city'] as String,
    latitude: (s['latitude'] as num).toDouble(),
    longitude: (s['longitude'] as num).toDouble(),
    rating: (s['rating'] as num?)?.toDouble() ?? 0,
    bestTime: s['bestTime'] ?? '',
    angle: s['angle'] ?? '',
    imageUrl: s['imageUrl'] ?? '',
    imageOriginalUrl: s['imageOriginalUrl'] ?? '',
    imageSourcePage: s['imageSourcePage'] ?? '',
    imageAuthor: s['imageAuthor'] ?? '',
    imageLicense: s['imageLicense'] ?? '',
    category: s['category'] ?? 'Genel',
    description: s['description'] ?? '',
    recommendedLens: s['recommendedLens'] ?? '',
    difficulty: s['difficulty'] ?? '',
    tags: List<String>.from(s['tags'] ?? []),
  );
}
