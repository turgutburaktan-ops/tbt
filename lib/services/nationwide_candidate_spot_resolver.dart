import '../data/official_photo_spot_candidates.dart';
import '../data/official_photo_spot_candidates_supplement.dart';
import '../data/turkiye81_spot_candidates.dart';
import '../data/turkiye81_spot_coordinates.dart';
import '../models/photo_spot.dart';

/// Türkiye genelindeki tüm kaynak adaylarını tek akışta koordinatlı PhotoSpot
/// kayıtlarıyla eşleştirir. Uygulama içinde harici geocoding API çağrısı yapmaz.
class NationwideCandidateSpotResolver {
  NationwideCandidateSpotResolver._();

  static List<OfficialSpotCandidate> get allCandidates {
    final byKey = <String, OfficialSpotCandidate>{};
    for (final candidate in <OfficialSpotCandidate>[
      ...officialPhotoSpotCandidates,
      ...officialPhotoSpotCandidatesSupplement,
      ...turkiye81SpotCandidates,
    ]) {
      byKey.putIfAbsent(_placeKey(candidate.city, candidate.name), () => candidate);
    }
    return List.unmodifiable(byKey.values);
  }

  static List<PhotoSpot> mergeInto(List<PhotoSpot> current) {
    final resultByPlace = <String, PhotoSpot>{
      for (final spot in current) _placeKey(spot.city, spot.name): spot,
    };

    final currentByCity = <String, List<PhotoSpot>>{};
    for (final spot in current) {
      currentByCity.putIfAbsent(_normalize(spot.city), () => <PhotoSpot>[]).add(spot);
    }

    for (final candidate in allCandidates) {
      final exactKey = _placeKey(candidate.city, candidate.name);
      if (resultByPlace.containsKey(exactKey)) continue;

      // 81 il ana havuzunda doğrulanmış statik koordinat varsa doğrudan kullan.
      final explicit = turkiye81SpotCoordinates[candidate.id];
      if (explicit != null) {
        resultByPlace[exactKey] = _fromCandidate(
          candidate,
          latitude: explicit.latitude,
          longitude: explicit.longitude,
        );
        continue;
      }

      // Aynı kaynak noktası daha önce kürasyon kataloğuna farklı bir adla
      // alınmışsa koordinatını tekrar kullan. Şehir dışına asla eşleştirme yapma.
      final citySpots = currentByCity[_normalize(candidate.city)] ?? const <PhotoSpot>[];
      final matched = _bestExistingMatch(candidate.name, citySpots);
      if (matched != null) {
        resultByPlace[exactKey] = _fromCandidate(
          candidate,
          latitude: matched.latitude,
          longitude: matched.longitude,
          imageUrl: matched.imageUrl,
          bestTime: matched.bestTime,
          angle: matched.angle,
          lens: matched.recommendedLens,
          difficulty: matched.difficulty,
          description: matched.description,
          rating: matched.rating,
        );
      }
    }

    final result = resultByPlace.values.toList()
      ..sort((a, b) {
        final city = a.city.compareTo(b.city);
        return city != 0 ? city : a.name.compareTo(b.name);
      });
    return result;
  }

  static PhotoSpot _fromCandidate(
    OfficialSpotCandidate candidate, {
    required double latitude,
    required double longitude,
    String imageUrl = '',
    String bestTime = 'Altın saat ve gün ışığı koşullarına göre planla',
    String angle = 'Ana manzarayı ve çevresel detayları farklı açılardan değerlendir',
    String lens = '24-70mm',
    String difficulty = 'Kolay',
    String description = '',
    double rating = 0,
  }) {
    return PhotoSpot(
      id: candidate.id,
      name: candidate.name,
      city: candidate.city,
      latitude: latitude,
      longitude: longitude,
      rating: rating,
      bestTime: bestTime,
      angle: angle,
      imageUrl: imageUrl,
      category: candidate.suggestedCategory,
      description: description,
      recommendedLens: lens,
      difficulty: difficulty,
      tags: const ['Türkiye', 'kaynak-teyitli'],
    );
  }

  static PhotoSpot? _bestExistingMatch(String candidateName, List<PhotoSpot> spots) {
    final candidateTokens = _tokens(candidateName);
    if (candidateTokens.isEmpty) return null;

    PhotoSpot? best;
    double bestScore = 0;
    for (final spot in spots) {
      final spotTokens = _tokens(spot.name);
      if (spotTokens.isEmpty) continue;

      final shared = candidateTokens.intersection(spotTokens);
      if (shared.isEmpty) continue;

      final union = candidateTokens.union(spotTokens);
      final score = shared.length / union.length;
      final hasDistinctiveSharedToken = shared.any((token) => token.length >= 5);
      if (!hasDistinctiveSharedToken) continue;

      // Yanlış pin riskini azaltmak için güçlü benzerlik iste.
      if (score >= 0.5 && score > bestScore) {
        best = spot;
        bestScore = score;
      }
    }
    return best;
  }

  static Set<String> _tokens(String value) {
    const ignored = <String>{
      've', 'ile', 'eski', 'tarihi', 'merkezi', 'merkez', 'cevresi', 'noktasi',
      'panorama', 'seyir', 'fotograf', 'milli', 'parki', 'ilce', 'kasabasi',
    };
    return _normalize(value)
        .split(' ')
        .where((token) => token.length >= 3 && !ignored.contains(token))
        .toSet();
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
