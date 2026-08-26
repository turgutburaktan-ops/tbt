import 'spot_coordinate_verification_registry.dart';

/// Sekizinci doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch8 =
    <String, SpotCoordinateVerificationEvidence>{
      'sardes-antik-kenti': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata (World Heritage Site)',
        sourceRef: 'Q64735723',
        verifiedAt: '2026-08-20',
      ),
      'laodikeia': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q849709',
        verifiedAt: '2026-08-20',
      ),
      'sagalassos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q279191',
        verifiedAt: '2026-08-20',
      ),
      'kibyra': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1643467',
        verifiedAt: '2026-08-20',
      ),
      'phaselis': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q595329',
        verifiedAt: '2026-08-20',
      ),
      'olympos-antik-kenti': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1380189',
        verifiedAt: '2026-08-20',
      ),
      'termessos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q599462',
        verifiedAt: '2026-08-20',
      ),
      'side-antik-kenti': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata (Side Roman Theatre anchor) + muze.gov.tr',
        sourceRef: 'Q19368273 / SDO01',
        verifiedAt: '2026-08-20',
      ),
      'aizanoi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q411571',
        verifiedAt: '2026-08-20',
      ),
      'priene': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q142819',
        verifiedAt: '2026-08-20',
      ),
      'miletos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q169460',
        verifiedAt: '2026-08-20',
      ),
      'didyma-apollon': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q5805723',
        verifiedAt: '2026-08-20',
      ),
    };

bool isSpotCoordinateIndependentlyVerifiedBatch8(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch8.containsKey(spotId);
