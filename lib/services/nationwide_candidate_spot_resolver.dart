import '../data/verified_travel_places.dart';
import '../data/verified_travel_places_batch2.dart';
import '../data/verified_travel_places_batch3.dart';
import '../data/verified_travel_places_batch4.dart';
import '../data/verified_travel_places_batch5.dart';
import '../data/verified_travel_places_batch6.dart';
import '../data/verified_travel_places_batch7.dart';
import '../data/verified_travel_places_batch8.dart';
import '../data/verified_travel_places_batch9.dart';
import '../data/verified_travel_places_batch10.dart';
import '../data/verified_travel_places_batch11.dart';
import '../data/verified_travel_places_batch12.dart';
import '../data/verified_travel_places_generated.dart';
import '../data/curated_photo_spots_verified_expansion.dart';
import '../data/curated_photo_spots_official_complete.dart';
import '../models/photo_spot.dart';

/// Kullanıcıya açık katalog yalnızca güvenilir kaynakları kabul eder:
/// 1) Elle kaynak kontrolü tamamlanmış doğrulanmış gezi çekirdeği.
/// 2) Doğrudan P625 + P18 + Commons lisans/çözünürlük kapısından geçmiş
///    kaynak-doğrulanmış üretim kataloğu.
/// 3) Firestore'da koordinat + görsel doğrulaması tamamlanmış kayıtlar.
class NationwideCandidateSpotResolver {
  NationwideCandidateSpotResolver._();

  static List<PhotoSpot> mergeInto(List<PhotoSpot> current) {
    final resultByPlace = <String, PhotoSpot>{};

    for (final spot in current) {
      if (!_trustedExistingSpot(spot)) continue;
      resultByPlace[_placeKey(spot.city, spot.name)] = spot;
    }

    for (final verified in <PhotoSpot>[
      ...verifiedTravelPlaces,
      ...verifiedTravelPlacesBatch2,
      ...verifiedTravelPlacesBatch3,
      ...verifiedTravelPlacesBatch4,
      ...verifiedTravelPlacesBatch5,
      ...verifiedTravelPlacesBatch6,
      ...verifiedTravelPlacesBatch7,
      ...verifiedTravelPlacesBatch8,
      ...verifiedTravelPlacesBatch9,
      ...verifiedTravelPlacesBatch10,
      ...verifiedTravelPlacesBatch11,
      ...verifiedTravelPlacesBatch12,
      ...verifiedTravelPlacesGenerated,
      ...curatedPhotoSpotsVerifiedExpansion,
      ...curatedPhotoSpotsOfficialComplete,
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

  static bool _trustedExistingSpot(PhotoSpot spot) =>
      spot.tags.contains('Doğrulanmış') ||
      spot.tags.contains('FirestoreDoğrulanmış');

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
