import 'dart:math' as math;

import '../models/photo_spot.dart';

/// Client contract for the shared, server-reviewed photo_spots collection.
/// Source/P18/license/district evidence must be checked before publication.
class PublishedSpotCatalog {
  static Future<List<T>> collectPages<T>(
    Future<List<T>> Function(T? cursor, int pageSize) fetch,
  ) async {
    final result = <T>[];
    T? cursor;
    while (true) {
      final page = await fetch(cursor, 500);
      result.addAll(page);
      if (page.length < 500) return result;
      if (identical(cursor, page.last)) throw StateError('Catalog cursor did not advance');
      cursor = page.last;
    }
  }

  static PhotoSpot? decode(String id, Map<String, dynamic> data) {
    if (data['status'] != 'published' ||
        data['coordinateVerified'] != true || data['imageVerified'] != true) {
      return null;
    }
    final name = text(data['name']);
    final city = text(data['city']);
    final lat = number(data['latitude']);
    final lng = number(data['longitude']);
    final image = text(data['imageUrl']);
    final uri = Uri.tryParse(image);
    if (id.isEmpty || name.isEmpty || city.isEmpty ||
        lat == null || lng == null ||
        lat < 35.4 || lat > 42.3 || lng < 25.4 || lng > 45.1 ||
        uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) return null;
    return PhotoSpot(
      id: id, name: name, city: city, latitude: lat, longitude: lng,
      imageUrl: image, rating: (number(data['rating']) ?? 0).clamp(0, 5).toDouble(),
      imageOriginalUrl: commonsUrl(data['imageOriginalUrl']),
      imageSourcePage: commonsUrl(data['imageSourcePage']),
      imageAuthor: text(data['imageAuthor']),
      imageLicense: text(data['imageLicense']),
      bestTime: text(data['bestTime']), angle: text(data['angle']),
      category: text(data['category']).isEmpty ? 'Genel' : text(data['category']),
      description: text(data['description']),
      recommendedLens: text(data['recommendedLens']),
      difficulty: text(data['difficulty']),
      tags: <String>{
        'FirestoreDoğrulanmış',
        if (text(data['district']).isNotEmpty) text(data['district']),
        if (data['tags'] is List)
          ...(data['tags'] as List).whereType<String>().where((s) => s.trim().isNotEmpty),
      }.toList(),
    );
  }

  static String text(dynamic value) => value is String ? value.trim() : '';

  static String commonsUrl(dynamic value) {
    final source = text(value);
    final uri = Uri.tryParse(source);
    return uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty &&
        const {'upload.wikimedia.org', 'thumb.wikimedia.org', 'commons.wikimedia.org'}.contains(uri.host)
        ? source : '';
  }
  static double? number(dynamic value) {
    final n = value is num ? value.toDouble() :
        value is String ? double.tryParse(value.trim()) : null;
    return n != null && n.isFinite ? n : null;
  }

  static String nameKey(String value) => value.replaceAll('İ', 'i')
      .toLowerCase().replaceAll('ı', 'i').replaceAll('ş', 's')
      .replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ö', 'o')
      .replaceAll('ç', 'c').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Same stable ID order and 18m/name exclusion as the web reader.
  static List<PhotoSpot> filter(List<PhotoSpot> input) {
    final sorted = [...input]..sort((a, b) => a.id.compareTo(b.id));
    final ids = <String>{}, names = <String>{};
    final cells = <String, List<PhotoSpot>>{};
    final result = <PhotoSpot>[];
    for (final spot in sorted) {
      final name = nameKey(spot.name);
      if (ids.contains(spot.id) || names.contains(name)) continue;
      final x = (spot.latitude * 1000).floor();
      final y = (spot.longitude * 1000).floor();
      var duplicate = false;
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final other in cells['${x + dx}:${y + dy}'] ?? <PhotoSpot>[]) {
            if (_meters(spot, other) <= 18) duplicate = true;
          }
        }
      }
      if (duplicate) continue;
      ids.add(spot.id); names.add(name); result.add(spot);
      cells.putIfAbsent('$x:$y', () => []).add(spot);
    }
    return result;
  }

  static double _meters(PhotoSpot a, PhotoSpot b) {
    const k = math.pi / 180;
    final h = math.pow(math.sin((b.latitude - a.latitude) * k / 2), 2) +
        math.cos(a.latitude * k) * math.cos(b.latitude * k) *
        math.pow(math.sin((b.longitude - a.longitude) * k / 2), 2);
    return 12742000 * math.asin(math.sqrt(h.clamp(0, 1)));
  }
}
