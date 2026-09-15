import 'spot_coordinate_verification_registry.dart';

/// Altıncı doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch6 =
    <String, SpotCoordinateVerificationEvidence>{
      'zilkale': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q8071903',
        verifiedAt: '2026-08-20',
      ),
      'giresun-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6041896',
        verifiedAt: '2026-08-20',
      ),
      'trabzon-ataturk-kosku': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6025611',
        verifiedAt: '2026-08-20',
      ),
      'erzurum-cifte-minareli-medrese': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q8077698',
        verifiedAt: '2026-08-20',
      ),
      'van-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q3187042',
        verifiedAt: '2026-08-20',
      ),
      'arslantepe': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + UNESCO',
        sourceRef: 'Q705132 / UNESCO 1622',
        verifiedAt: '2026-08-20',
      ),
      'mor-gabriel-manastiri': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1434981',
        verifiedAt: '2026-08-20',
      ),
      'girlevik-selalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q5627140',
        verifiedAt: '2026-08-20',
      ),
      'rumkale': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1477613',
        verifiedAt: '2026-08-20',
      ),
      'cavustepe-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q272699',
        verifiedAt: '2026-08-20',
      ),
      'tortum-selalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1337971',
        verifiedAt: '2026-08-20',
      ),
      'karanlik-kanyon': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + UNESCO tentative list',
        sourceRef: 'Q61077683 / Tentative 6535',
        verifiedAt: '2026-08-20',
      ),
    };

bool isSpotCoordinateIndependentlyVerifiedBatch6(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch6.containsKey(spotId);
