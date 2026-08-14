import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/photo_spot.dart';

class SpotImageSearchService {
  SpotImageSearchService._();
  static final SpotImageSearchService instance = SpotImageSearchService._();

  final Map<String, String?> _cache = <String, String?>{};
  final Map<String, Future<String?>> _pending = <String, Future<String?>>{};

  Future<String?> findImage(PhotoSpot spot) {
    final key = '${spot.id}|${spot.city}|${spot.name}';
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _pending.putIfAbsent(key, () => _search(key, spot));
  }

  Future<String?> _search(String key, PhotoSpot spot) async {
    try {
      final query = '${spot.name} ${spot.city} Türkiye Turkey filetype:bitmap';
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': query,
        'gsrnamespace': '6',
        'gsrlimit': '6',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'iiurlwidth': '1280',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      });

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'BestPhotoSpot/0.1 (photo spot image resolver)',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        _cache[key] = null;
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _cache[key] = null;
        return null;
      }

      final queryData = decoded['query'];
      if (queryData is! Map<String, dynamic>) {
        _cache[key] = null;
        return null;
      }

      final pages = queryData['pages'];
      if (pages is! List || pages.isEmpty) {
        _cache[key] = null;
        return null;
      }

      final ranked = pages.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) => _score(b, spot).compareTo(_score(a, spot)));

      for (final page in ranked) {
        if (_score(page, spot) <= 0) continue;
        final imageInfo = page['imageinfo'];
        if (imageInfo is! List || imageInfo.isEmpty) continue;
        final info = imageInfo.first;
        if (info is! Map<String, dynamic>) continue;
        final thumbUrl = (info['thumburl'] ?? info['url'] ?? '').toString().trim();
        if (thumbUrl.startsWith('https://')) {
          _cache[key] = thumbUrl;
          return thumbUrl;
        }
      }

      _cache[key] = null;
      return null;
    } catch (_) {
      _cache[key] = null;
      return null;
    } finally {
      _pending.remove(key);
    }
  }

  int _score(Map<String, dynamic> page, PhotoSpot spot) {
    final title = _normalize((page['title'] ?? '').toString());
    final name = _normalize(spot.name);
    final city = _normalize(spot.city);
    if (title.isEmpty) return 0;

    var score = 0;
    final nameTokens = name.split(' ').where((e) => e.length > 2).toSet();
    for (final token in nameTokens) {
      if (title.contains(token)) score += 4;
    }
    if (city.isNotEmpty && title.contains(city)) score += 2;
    if (title.contains('turkey') || title.contains('turkiye')) score += 1;
    return score;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
