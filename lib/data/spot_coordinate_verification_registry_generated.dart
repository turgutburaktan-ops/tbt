import 'spot_coordinate_verification_registry.dart';

/// `tool/generate_verified_spot_catalog.py` tarafından üretilir.
const verifiedSpotCoordinateEvidenceGenerated =
    <String, SpotCoordinateVerificationEvidence>{};

bool isSpotCoordinateIndependentlyVerifiedGenerated(String spotId) =>
    verifiedSpotCoordinateEvidenceGenerated.containsKey(spotId);
