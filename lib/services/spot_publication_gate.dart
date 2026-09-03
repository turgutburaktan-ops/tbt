import '../data/spot_coordinate_verification_registry.dart';
import '../data/spot_coordinate_verification_registry_batch5.dart';
import '../data/spot_coordinate_verification_registry_batch6.dart';
import '../data/spot_coordinate_verification_registry_batch7.dart';
import '../data/spot_coordinate_verification_registry_batch8.dart';
import '../data/spot_coordinate_verification_registry_batch9.dart';
import '../data/spot_coordinate_verification_registry_batch10.dart';
import '../data/spot_coordinate_verification_registry_batch11.dart';
import '../data/spot_coordinate_verification_registry_batch12.dart';
import '../data/spot_coordinate_verification_registry_generated.dart';
import '../data/spot_image_registry.dart';
import '../data/verified_travel_image_registry.dart';
import '../data/verified_travel_image_registry_batch2.dart';
import '../data/verified_travel_image_registry_batch3.dart';
import '../data/verified_travel_image_registry_batch4.dart';
import '../data/verified_travel_image_registry_batch5.dart';
import '../data/verified_travel_image_registry_batch6.dart';
import '../data/verified_travel_image_registry_batch7.dart';
import '../data/verified_travel_image_registry_batch8.dart';
import '../data/verified_travel_image_registry_batch9.dart';
import '../data/verified_travel_image_registry_batch10.dart';
import '../data/verified_travel_image_registry_batch11.dart';
import '../data/verified_travel_image_registry_batch12.dart';
import '../data/verified_travel_image_registry_generated.dart';
import '../models/photo_spot.dart';

/// A place reaches public discovery only after both its location and its
/// location-specific photo have been verified. Incomplete records remain in
/// candidate catalogs until both checks are complete.
class SpotPublicationGate {
  SpotPublicationGate._();

  /// These automatic matches were reviewed and found to show another place.
  /// They must not count as a verified photo.
  static const rejectedImageSpotIds = <String>{
    'elazig-agin-tarihi-evleri',
    'elazig-bakircilar-carsisi-complete',
    'elazig-meryem-ana-kilisesi',
    'elazig-palu-tas-koprusu',
    'elz-agin',
    'elz-bakircilar',
    'elz-eski-hukumet',
    'elz-kapalicarsi',
    'elz-meryem-ana',
    'elz-palu-kilise',
  };

  static bool canPublish(PhotoSpot spot) {
    // Firestore records receive this tag only after both review flags are true.
    if (spot.tags.contains('FirestoreDoğrulanmış')) {
      return spot.imageUrl.trim().isNotEmpty;
    }
    return hasVerifiedCoordinates(spot.id) && hasVerifiedImage(spot.id);
  }

  static bool hasVerifiedCoordinates(String spotId) =>
      isSpotCoordinateIndependentlyVerified(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch5(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch6(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch7(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch8(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch9(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch10(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch11(spotId) ||
      isSpotCoordinateIndependentlyVerifiedBatch12(spotId) ||
      isSpotCoordinateIndependentlyVerifiedGenerated(spotId);

  static bool hasVerifiedImage(String spotId) {
    if (rejectedImageSpotIds.contains(spotId)) return false;
    final image =
        verifiedTravelImageRegistryGenerated[spotId] ??
        verifiedTravelImageRegistryBatch12[spotId] ??
        verifiedTravelImageRegistryBatch11[spotId] ??
        verifiedTravelImageRegistryBatch10[spotId] ??
        verifiedTravelImageRegistryBatch9[spotId] ??
        verifiedTravelImageRegistryBatch8[spotId] ??
        verifiedTravelImageRegistryBatch7[spotId] ??
        verifiedTravelImageRegistryBatch6[spotId] ??
        verifiedTravelImageRegistryBatch5[spotId] ??
        verifiedTravelImageRegistryBatch4[spotId] ??
        verifiedTravelImageRegistryBatch3[spotId] ??
        verifiedTravelImageRegistryBatch2[spotId] ??
        verifiedTravelImageRegistry[spotId] ??
        spotImageRegistry[spotId];
    // Public cards use the compact remote catalog. An asset-only registry row
    // may refer to a source file intentionally excluded from the app bundle;
    // publishing it would create a photo-less card on the user's device.
    return image != null && image.networkUrl.trim().isNotEmpty;
  }
}
