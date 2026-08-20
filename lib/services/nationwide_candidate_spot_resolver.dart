import '../data/official_photo_spot_candidates.dart';
import '../data/official_photo_spot_candidates_supplement.dart';
import '../data/spot_coordinate_verification_registry.dart';
import '../data/turkiye81_spot_candidates.dart';
import '../data/turkiye81_spot_coordinates.dart';
import '../data/verified_travel_places.dart';
import '../data/verified_travel_places_batch2.dart';
import '../data/verified_travel_places_batch3.dart';
import '../data/verified_travel_places_batch4.dart';
import '../models/photo_spot.dart';

/// Türkiye genelindeki kaynak adaylarını yalnızca kendilerine ait açıkça
/// tanımlanmış koordinatlar varsa uygulama kataloğuna dahil eder.
///
/// Kalite kuralı: isim benzerliği, aynı şehirde bulunma veya başka bir kaydın
/// konumu hiçbir zaman koordinat kaynağı olarak kullanılamaz. Böylece yanlış
/// pin üretmek yerine koordinatı bulunmayan aday görünmez kalır.
class NationwideCandidateSpotResolver {
  NationwideCandidateSpotResolver._();

  static List<OfficialSpotCandidate> get allCandidates {
    final byKey = <String, OfficialSpotCandidate>{};
    for (final candidate in <OfficialSpotCandidate>[
      ...officialPhotoSpotCandidates,
      ...officialPhotoSpotCandidatesSupplement,
      ...turkiye81SpotCandidates,
    ]) {
      byKey.putIfAbsent(
        _placeKey(candidate.city, candidate.name),
        () => candidate,
      );
    }
    return List.unmodifiable(byKey.values);
  }

  static List<PhotoSpot> mergeInto(List<PhotoSpot> current) {
    final resultByPlace = <String, PhotoSpot>{
      for (final spot in current) _placeKey(spot.city, spot.name): spot,
    };

    for (final candidate in allCandidates) {
      final exactKey = _placeKey(candidate.city, candidate.name);
      if (resultByPlace.containsKey(exactKey)) continue;

      // Yalnızca adayın kendi ID'sine ait açık koordinat kaydı kabul edilir.
      final explicit = turkiye81SpotCoordinates[candidate.id];
      if (explicit == null) continue;

      resultByPlace[exactKey] = _fromCandidate(
        candidate,
        latitude: explicit.latitude,
        longitude: explicit.longitude,
      );
    }

    // Elle kaynak kontrolü tamamlanan gezilecek yer çekirdeği her zaman son
    // sözü söyler. Aynı ID eski demo/otomatik katalogda başka ad veya pinle
    // bulunuyorsa önce kaldırılır; böylece doğrulanmış koordinat ezilemez.
    for (final verified in <PhotoSpot>[
      ...verifiedTravelPlaces,
      ...verifiedTravelPlacesBatch2,
      ...verifiedTravelPlacesBatch3,
      ...verifiedTravelPlacesBatch4,
    ]) {
      resultByPlace.removeWhere((_, spot) => spot.id == verified.id);
      resultByPlace[_placeKey(verified.city, verified.name)] = verified;
    }

    final result = resultByPlace.values.toList()
      ..sort((a, b) {
        final aVerified = a.tags.contains('Doğrulanmış');
        final bVerified = b.tags.contains('Doğrulanmış');
        if (aVerified != bVerified) return aVerified ? -1 : 1;
        final city = a.city.compareTo(b.city);
        return city != 0 ? city : a.name.compareTo(b.name);
      });
    return result;
  }

  static PhotoSpot _fromCandidate(
    OfficialSpotCandidate candidate, {
    required double latitude,
    required double longitude,
  }) {
    final verified = isSpotCoordinateIndependentlyVerified(candidate.id);
    return PhotoSpot(
      id: candidate.id,
      name: candidate.name,
      city: candidate.city,
      latitude: latitude,
      longitude: longitude,
      rating: 0,
      bestTime: 'Altın saat ve gün ışığı koşullarına göre planla',
      angle: 'Ana manzarayı ve çevresel detayları farklı açılardan değerlendir',
      imageUrl: '',
      category: candidate.suggestedCategory,
      description: '',
      recommendedLens: '24-70mm',
      difficulty: 'Kolay',
      tags: verified
          ? const ['Türkiye', 'koordinat-dogrulandi']
          : const ['Türkiye', 'koordinat-kayitli'],
    );
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
