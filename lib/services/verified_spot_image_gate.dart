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

/// Yalnizca kaynak, yazar ve lisans bilgisi elle ya da veri uretim
/// kapisinda dogrulanmis gorselleri katalogda yayina uygun sayar.
bool hasVerifiedSpotImage(String spotId) {
  final info =
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
      verifiedTravelImageRegistry[spotId];
  if (info == null) return false;
  return info.sourcePage.trim().isNotEmpty &&
      info.sourceName.trim().isNotEmpty &&
      info.author.trim().isNotEmpty &&
      info.license.trim().isNotEmpty &&
      (info.assetPath.trim().isNotEmpty || info.networkUrl.trim().isNotEmpty);
}
