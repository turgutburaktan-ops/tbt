import '../models/photo_spot.dart';

/// Son savunma hattı: katalog kaynaklarından bağımsız olarak haritaya çıkmadan
/// önce bariz hatalı veya çakışan koordinatları eler.
class SpotQualityGate {
  SpotQualityGate._();

  // Türkiye + yakın kıyı/adalar için yeterince geniş, yanlış ülke pinlerini
  // yakalayacak kadar dar güvenlik sınırı.
  static const double _minLat = 35.4;
  static const double _maxLat = 42.3;
  static const double _minLng = 25.4;
  static const double _maxLng = 45.1;

  /// Manuel denetimde hatalı olduğu kesinleşen kayıtlar buraya alınır.
  /// Bu liste büyüdükçe kullanıcıya hiçbir zaman yanlış pin gösterilmez.
  static const Set<String> blockedSpotIds = <String>{};

  static List<PhotoSpot> filterSafe(List<PhotoSpot> input) {
    final valid = input.where(_basicCoordinateCheck).toList();

    // 5 ondalık basamak yaklaşık metre seviyesinde aynı pini temsil eder.
    // Farklı isim/şehirlerin birebir aynı pini paylaşması otomatik veri
    // çoğaltmanın güçlü işaretidir; doğrulanana kadar tamamını gizleriz.
    final byCoordinate = <String, List<PhotoSpot>>{};
    for (final spot in valid) {
      final key = '${spot.latitude.toStringAsFixed(5)}|'
          '${spot.longitude.toStringAsFixed(5)}';
      byCoordinate.putIfAbsent(key, () => <PhotoSpot>[]).add(spot);
    }

    final suspiciousIds = <String>{};
    for (final group in byCoordinate.values) {
      if (group.length < 2) continue;
      final placeKeys = group.map((spot) => _placeKey(spot.city, spot.name)).toSet();
      if (placeKeys.length > 1) {
        suspiciousIds.addAll(group.map((spot) => spot.id));
      }
    }

    return valid
        .where((spot) =>
            !blockedSpotIds.contains(spot.id) && !suspiciousIds.contains(spot.id))
        .toList(growable: false);
  }

  static bool _basicCoordinateCheck(PhotoSpot spot) {
    if (blockedSpotIds.contains(spot.id)) return false;
    if (!spot.latitude.isFinite || !spot.longitude.isFinite) return false;
    if (spot.latitude == 0 || spot.longitude == 0) return false;
    return spot.latitude >= _minLat &&
        spot.latitude <= _maxLat &&
        spot.longitude >= _minLng &&
        spot.longitude <= _maxLng;
  }

  static String _placeKey(String city, String name) =>
      '${_normalize(city)}|${_normalize(name)}';

  static String _normalize(String value) => value
      .trim()
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
