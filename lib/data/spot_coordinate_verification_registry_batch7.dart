import 'spot_coordinate_verification_registry.dart';

/// Yedinci doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch7 =
    <String, SpotCoordinateVerificationEvidence>{
      'kars-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q5050393',
        verifiedAt: '2026-08-20',
      ),
      'cildir-golu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q272986',
        verifiedAt: '2026-08-20',
      ),
      'yason-burnu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1969910',
        verifiedAt: '2026-08-20',
      ),
      'hamsilos-tabiat-parki': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + OpenStreetMap',
        sourceRef: 'Q6039198 / OSM way 892954547',
        verifiedAt: '2026-08-20',
      ),
      'amasra-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Kültür Envanteri + OpenStreetMap',
        sourceRef: 'KE 3097 / 41.7496868443599,32.387102837540596',
        verifiedAt: '2026-08-20',
      ),
      'amasya-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q21524009',
        verifiedAt: '2026-08-20',
      ),
      'gordion': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + UNESCO',
        sourceRef: 'Q542854 / UNESCO 1669',
        verifiedAt: '2026-08-20',
      ),
      'ballica-magarasi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q4852313',
        verifiedAt: '2026-08-20',
      ),
      'alacahoyuk': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q558861',
        verifiedAt: '2026-08-20',
      ),
      'midas-aniti': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q110661070',
        verifiedAt: '2026-08-20',
      ),
      'ayazini-metropolisi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q118956350',
        verifiedAt: '2026-08-20',
      ),
      'catalhoyuk': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + UNESCO',
        sourceRef: 'Q192522 / UNESCO 1405',
        verifiedAt: '2026-08-20',
      ),
    };

bool isSpotCoordinateIndependentlyVerifiedBatch7(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch7.containsKey(spotId);
