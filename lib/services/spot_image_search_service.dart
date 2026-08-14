import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_spot.dart';

class SpotImageSearchService {
  SpotImageSearchService._();
  static final SpotImageSearchService instance = SpotImageSearchService._();

  final Map<String, String?> _cache = <String, String?>{};
  final Map<String, Future<String?>> _pending = <String, Future<String?>>{};

  static const Map<String, List<String>> _aliases = {
    'elazig-meryem-ana-kilisesi': [
      'Harput Meryem Ana Kilisesi',
      'Harput Süryani Kilisesi',
      'Harput Yakubi Kilisesi',
      'Harput Kızıl Kilise',
    ],
    'elz-meryem-ana': [
      'Harput Meryem Ana Kilisesi',
      'Harput Süryani Kilisesi',
      'Harput Yakubi Kilisesi',
      'Harput Kızıl Kilise',
    ],
    'elazig-alacali-camii': ['Harput Alacalı Camii'],
    'elz-alacali-cami': ['Harput Alacalı Camii'],
    'elazig-harput-ulu-camii': ['Harput Ulu Camii'],
    'elz-harput-ulu': ['Harput Ulu Camii'],
  };

  Future<String?> findImage(PhotoSpot spot) {
    final key = _key(spot);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _pending.putIfAbsent(key, () => _loadOrSearch(key, spot));
  }

  Future<void> invalidate(PhotoSpot spot, [String? failedUrl]) async {
    final key = _key(spot);
    final current = _cache[key];
    if (failedUrl == null || current == failedUrl) {
      _cache.remove(key);
      _pending.remove(key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(key));
    }
  }

  String _key(PhotoSpot spot) => '${spot.id}|${spot.city}|${spot.name}';

  Future<String?> _loadOrSearch(String key, PhotoSpot spot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey(key))?.trim() ?? '';
      if (saved.startsWith('https://')) {
        _cache[key] = saved;
        return saved;
      }
      return await _search(key, spot, prefs);
    } finally {
      _pending.remove(key);
    }
  }

  Future<String?> _search(
    String key,
    PhotoSpot spot,
    SharedPreferences prefs,
  ) async {
    final queries = _queries(spot);

    // Önce Wikimedia Commons: açık lisanslı ve doğrudan görsel kaynağı.
    for (final query in queries) {
      final found = await _searchCommons(query, spot);
      if (found != null) return _save(key, found, prefs);
    }

    // Commons dosya adları bazen İngilizce olduğu için Türkçe Wikipedia sayfa
    // görseli ikinci güvenilir kaynak olarak denenir.
    for (final query in queries.take(6)) {
      final found = await _searchTurkishWikipedia(query, spot);
      if (found != null) return _save(key, found, prefs);
    }

    // Küçük ve yerel noktaların Commons dosya adı farklı olabiliyor. Son çare
    // olarak yalnızca noktaya yakın ve başlık eşleşmesi olan Commons medyasını
    // kullan. Böylece rastgele şehir fotoğrafı seçme riskini düşük tutuyoruz.
    final nearby = await _searchCommonsNearby(spot);
    if (nearby != null) return _save(key, nearby, prefs);

    _cache[key] = null;
    return null;
  }

  Future<String?> _save(
    String key,
    String url,
    SharedPreferences prefs,
  ) async {
    _cache[key] = url;
    await prefs.setString(_prefsKey(key), url);
    return url;
  }

  Future<String?> _searchCommons(String query, PhotoSpot spot) async {
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': query,
        'gsrnamespace': '6',
        'gsrlimit': '20',
        'prop': 'imageinfo|coordinates',
        'iiprop': 'url',
        'iiurlwidth': '1000',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      });
      final response = await _get(uri);
      if (response == null) return null;
      final pages = _pages(response);
      if (pages.isEmpty) return null;

      pages.sort((a, b) => _score(b, spot).compareTo(_score(a, spot)));
      for (final page in pages) {
        if (_score(page, spot) < 4) continue;
        final url = _imageUrl(page);
        if (url != null) return url;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _searchCommonsNearby(PhotoSpot spot) async {
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'geosearch',
        'ggsprimary': 'all',
        'ggsnamespace': '6',
        'ggsradius': '1600',
        'ggslimit': '40',
        'ggscoord': '${spot.latitude}|${spot.longitude}',
        'prop': 'imageinfo|coordinates',
        'iiprop': 'url',
        'iiurlwidth': '1000',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      });
      final response = await _get(uri);
      if (response == null) return null;
      final pages = _pages(response);
      if (pages.isEmpty) return null;

      pages.sort((a, b) {
        final scoreCompare = _score(b, spot).compareTo(_score(a, spot));
        if (scoreCompare != 0) return scoreCompare;
        return (_distanceMeters(a, spot) ?? double.infinity)
            .compareTo(_distanceMeters(b, spot) ?? double.infinity);
      });

      for (final page in pages) {
        final score = _score(page, spot);
        final distance = _distanceMeters(page, spot);
        // En az bir anlamlı ad/alias eşleşmesi şart. Mesafe tek başına yeterli
        // değildir; komşu bir yapının fotoğrafını yanlış göstermeyelim.
        if (score < 4) continue;
        if (distance != null && distance > 1600) continue;
        final url = _imageUrl(page);
        if (url != null) return url;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _searchTurkishWikipedia(
    String query,
    PhotoSpot spot,
  ) async {
    try {
      final uri = Uri.https('tr.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': query,
        'gsrnamespace': '0',
        'gsrlimit': '10',
        'prop': 'pageimages',
        'piprop': 'thumbnail',
        'pithumbsize': '1000',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      });
      final response = await _get(uri);
      if (response == null) return null;
      final pages = _pages(response);
      if (pages.isEmpty) return null;

      pages.sort((a, b) => _score(b, spot).compareTo(_score(a, spot)));
      for (final page in pages) {
        if (_score(page, spot) < 4) continue;
        final thumbnail = page['thumbnail'];
        if (thumbnail is! Map<String, dynamic>) continue;
        final url = (thumbnail['source'] ?? '').toString().trim();
        if (_usableImageUrl(url)) return url;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _get(Uri uri) async {
    try {
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent':
              'BestPhotoSpot/1.0 (https://github.com/turgutburaktan-ops/tbt; contact: turgutburaktan@gmail.com)',
          'Accept': 'application/json',
          'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.7',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _pages(Map<String, dynamic> decoded) {
    final queryData = decoded['query'];
    if (queryData is! Map<String, dynamic>) return <Map<String, dynamic>>[];
    final pages = queryData['pages'];
    if (pages is! List) return <Map<String, dynamic>>[];
    return pages.whereType<Map<String, dynamic>>().toList();
  }

  List<String> _queries(PhotoSpot spot) {
    final name = spot.name.trim();
    final city = spot.city.trim();
    final expanded = _englishExpansion(name);
    final aliases = _aliases[spot.id] ?? const <String>[];
    final values = <String>[
      ...aliases,
      ...aliases.map((alias) => '$alias $city'),
      '$name $city',
      '$name Türkiye',
      '$name Turkey',
      name,
      if (expanded != name) '$expanded $city Turkey',
      if (expanded != name) expanded,
    ];
    final seen = <String>{};
    return values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && seen.add(_normalize(e)))
        .toList(growable: false);
  }

  String _englishExpansion(String value) {
    var text = _normalize(value);
    const replacements = <String, String>{
      ' camii': ' mosque',
      ' cami': ' mosque',
      ' kilisesi': ' church',
      ' kilise': ' church',
      ' kalesi': ' castle',
      ' kale': ' castle',
      ' koprusu': ' bridge',
      ' kopru': ' bridge',
      ' golu': ' lake',
      ' dagi': ' mountain',
      ' dag': ' mountain',
      ' vadisi': ' valley',
      ' sarayi': ' palace',
      ' saray': ' palace',
      ' muzesi': ' museum',
      ' muze': ' museum',
      ' selalesi': ' waterfall',
      ' magarasi': ' cave',
      ' plaji': ' beach',
      ' antik kenti': ' ancient city',
      ' tarihi': ' historic',
    };
    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text.trim();
  }

  String _prefsKey(String key) {
    final compact = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    // v4 yeni resolver/alias mantığıyla eski başarısız sonuçları taşımıyoruz.
    return 'spot_image_v4_$compact';
  }

  bool _usableImageUrl(String url) {
    if (!url.startsWith('https://')) return false;
    final lower = url.toLowerCase();
    return !lower.contains('.svg') &&
        !lower.contains('.pdf') &&
        !lower.contains('.djvu') &&
        !lower.contains('.tif');
  }

  String? _imageUrl(Map<String, dynamic> page) {
    final imageInfo = page['imageinfo'];
    if (imageInfo is! List || imageInfo.isEmpty) return null;
    final info = imageInfo.first;
    if (info is! Map<String, dynamic>) return null;
    final url = (info['thumburl'] ?? info['url'] ?? '').toString().trim();
    return _usableImageUrl(url) ? url : null;
  }

  int _score(Map<String, dynamic> page, PhotoSpot spot) {
    final title = _normalize((page['title'] ?? '').toString());
    if (title.isEmpty) return 0;

    final city = _normalize(spot.city);
    final nameTokens = _tokens(spot.name);
    final englishTokens = _tokens(_englishExpansion(spot.name));
    final aliasTokens = <String>{
      for (final alias in _aliases[spot.id] ?? const <String>[]) ..._tokens(alias),
    };
    final candidateTokens = <String>{
      ...nameTokens,
      ...englishTokens,
      ...aliasTokens,
    };

    var score = 0;
    for (final token in candidateTokens) {
      if (title.contains(token)) score += token.length >= 5 ? 5 : 3;
    }
    if (city.isNotEmpty && title.contains(city)) score += 2;
    if (title.contains('harput') &&
        ((_aliases[spot.id] ?? const <String>[])
                .any((alias) => _normalize(alias).contains('harput')) ||
            _normalize(spot.tags.join(' ')).contains('harput'))) {
      score += 3;
    }
    if (title.contains('turkey') || title.contains('turkiye')) score += 1;
    return score;
  }

  double? _distanceMeters(Map<String, dynamic> page, PhotoSpot spot) {
    final coordinates = page['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) return null;
    final first = coordinates.first;
    if (first is! Map<String, dynamic>) return null;
    final lat = _asDouble(first['lat']);
    final lon = _asDouble(first['lon']);
    if (lat == null || lon == null) return null;

    const earthRadius = 6371000.0;
    final lat1 = _radians(spot.latitude);
    final lat2 = _radians(lat);
    final dLat = _radians(lat - spot.latitude);
    final dLon = _radians(lon - spot.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double? _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  static double _radians(double degrees) => degrees * math.pi / 180;

  Set<String> _tokens(String value) {
    const ignored = <String>{
      've',
      'ile',
      'the',
      'eski',
      'tarihi',
      'historic',
      'merkezi',
      'merkez',
      'cevre',
      'cevresi',
    };
    return _normalize(value)
        .split(' ')
        .where((e) => e.length > 2 && !ignored.contains(e))
        .toSet();
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
