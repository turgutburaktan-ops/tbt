import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/data/curated_photo_spots_official_complete.dart';
import 'package:best_photo_spot/data/curated_photo_spots_verified_expansion.dart';
import 'package:best_photo_spot/data/verified_travel_places.dart';
import 'package:best_photo_spot/services/spot_publication_gate.dart';

void main() {
  test('publishes a place only with verified coordinates and image', () {
    final ayasofya = verifiedTravelPlaces.singleWhere(
      (spot) => spot.id == 'ayasofya',
    );
    expect(SpotPublicationGate.canPublish(ayasofya), isTrue);
  });

  test('keeps incomplete Elazig candidates out of public discovery', () {
    final candidates = [
      ...curatedPhotoSpotsVerifiedExpansion,
      ...curatedPhotoSpotsOfficialComplete,
    ];
    for (final id in <String>{
      'elazig-hazarbaba',
      'elazig-bakircilar-carsisi-complete',
      'elazig-kazim-efendi-complete',
    }) {
      final spot = candidates.singleWhere((candidate) => candidate.id == id);
      expect(
        SpotPublicationGate.canPublish(spot),
        isFalse,
        reason: '$id must wait in the candidate catalog',
      );
    }
  });
}
