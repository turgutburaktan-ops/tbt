import 'spot_coordinate_verification_registry.dart';

/// On birinci doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch11 =
    <String, SpotCoordinateVerificationEvidence>{
  'zerzevan-kalesi': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q28806346',
    verifiedAt: '2026-08-20',
  ),
  'malabadi-koprusu': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q3397053',
    verifiedAt: '2026-08-20',
  ),
  'karahantepe': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q104000481',
    verifiedAt: '2026-08-20',
  ),
  'arsameia': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q704167',
    verifiedAt: '2026-08-20',
  ),
  'cendere-koprusu': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q1058264',
    verifiedAt: '2026-08-20',
  ),
  'karakus-tumulusu': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q1728921',
    verifiedAt: '2026-08-20',
  ),
  'yeni-kale-kahta': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata + Adıyaman Belediyesi',
    sourceRef: 'Q126823917 / 37.948935,38.656652',
    verifiedAt: '2026-08-20',
  ),
};

bool isSpotCoordinateIndependentlyVerifiedBatch11(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch11.containsKey(spotId);
