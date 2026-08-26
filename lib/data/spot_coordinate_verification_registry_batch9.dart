import 'spot_coordinate_verification_registry.dart';

/// Dokuzuncu doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch9 =
    <String, SpotCoordinateVerificationEvidence>{
      'dolmabahce-sarayi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q274141',
        verifiedAt: '2026-08-20',
      ),
      'rumeli-hisari': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q90801',
        verifiedAt: '2026-08-20',
      ),
      'iznik-ayasofya': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Kültür Portalı',
        sourceRef: 'Q4430013 / kulturportali.gov.tr İznik Ayasofya',
        verifiedAt: '2026-08-20',
      ),
      'golyazi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q19576831',
        verifiedAt: '2026-08-20',
      ),
      'dupnisa-magarasi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Geographic Names Server',
        sourceRef: 'Q3658667 / GNS 12693379',
        verifiedAt: '2026-08-20',
      ),
      'kilitbahir-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6058053',
        verifiedAt: '2026-08-20',
      ),
      'cunda-taksiyarhis': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q132681800',
        verifiedAt: '2026-08-20',
      ),
      'acarlar-longozu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6074850',
        verifiedAt: '2026-08-20',
      ),
      'horma-kanyonu': SpotCoordinateVerificationEvidence(
        sourceName: 'Kültür Portalı + Wikimedia Commons GPS',
        sourceRef: 'Horma Kanyonu / 41.648925,33.144639',
        verifiedAt: '2026-08-20',
      ),
      'valla-kanyonu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q20474544',
        verifiedAt: '2026-08-20',
      ),
      'cehennemagzi-magaralari': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Kültür Portalı',
        sourceRef: 'Q24915631 / Cehennemağzı Mağaraları',
        verifiedAt: '2026-08-20',
      ),
      'gokgol-magarasi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q5626477',
        verifiedAt: '2026-08-20',
      ),
    };

bool isSpotCoordinateIndependentlyVerifiedBatch9(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch9.containsKey(spotId);
