import 'spot_image_registry.dart';

/// `tool/generate_verified_spot_catalog.py` tarafından üretilir.
/// Görseller fuzzy arama ile değil, doğrudan ilgili Wikidata öğesinin P18
/// alanından alınır.
const verifiedTravelImageRegistryGenerated = <String, SpotImageInfo>{};
