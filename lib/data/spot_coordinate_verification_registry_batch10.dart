import 'spot_coordinate_verification_registry.dart';

/// Onuncu doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch10 =
    <String, SpotCoordinateVerificationEvidence>{
      'alanya-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q81593',
        verifiedAt: '2026-08-20',
      ),
      'mamure-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1524213',
        verifiedAt: '2026-08-20',
      ),
      'kizkalesi-deniz-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1957163',
        verifiedAt: '2026-08-20',
      ),
      'alahan-manastiri': SpotCoordinateVerificationEvidence(
        sourceName: 'Kültür Envanteri + OpenStreetMap + muze.gov.tr',
        sourceRef: '36.791386,33.353561 / Alahan Monastery visitor complex',
        verifiedAt: '2026-08-20',
      ),
      'saint-pierre-kilisesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + muze.gov.tr',
        sourceRef: 'Q516472 / STP01',
        verifiedAt: '2026-08-20',
      ),
      'titus-tuneli': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q18926963',
        verifiedAt: '2026-08-20',
      ),
      'karatepe-aslantas': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q24914998',
        verifiedAt: '2026-08-20',
      ),
      'anavarza-antik-kenti': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Nomisma',
        sourceRef: 'Q219525 / anazarbus',
        verifiedAt: '2026-08-20',
      ),
      'uzuncaburc': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q61829627',
        verifiedAt: '2026-08-20',
      ),
      'kapuzbasi-selaleleri': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Geographic Names Server',
        sourceRef: 'Q6070960 / GNS 11116566',
        verifiedAt: '2026-08-20',
      ),
      'tarsus-selalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q7686789',
        verifiedAt: '2026-08-20',
      ),
      'soli-pompeiopolis': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Nomisma',
        sourceRef: 'Q656954 / soli-pompeiopolis',
        verifiedAt: '2026-08-20',
      ),
    };

bool isSpotCoordinateIndependentlyVerifiedBatch10(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch10.containsKey(spotId);
