import 'spot_coordinate_verification_registry.dart';

/// On ikinci doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch12 =
    <String, SpotCoordinateVerificationEvidence>{
      'koza-han': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6055245',
        verifiedAt: '2026-08-20',
      ),
      'yesil-turbe': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Wikimedia Commons geotag',
        sourceRef: 'Q8053362 / 40.181389,29.074722',
        verifiedAt: '2026-08-20',
      ),
      'bayezid-saglik-muzesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q4874490',
        verifiedAt: '2026-08-20',
      ),
      'sirince': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q4116807',
        verifiedAt: '2026-08-20',
      ),
      'ulubey-kanyonu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q12812366',
        verifiedAt: '2026-08-20',
      ),
      'akyaka-kadin-azmagi': SpotCoordinateVerificationEvidence(
        sourceName: 'HaritaTR + local visitor mapping',
        sourceRef: '37.0531,28.3300 / Kadın Azmağı',
        verifiedAt: '2026-08-20',
      ),
      'st-nicholas-demre': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikimedia Commons geotag + muze.gov.tr',
        sourceRef: 'St. Nicholas Church, Demre / 36.244590,29.985195',
        verifiedAt: '2026-08-20',
      ),
      'koprulu-kanyon': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6034089',
        verifiedAt: '2026-08-20',
      ),
      'kanlidivane': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + OpenStreetMap',
        sourceRef: 'Q202974 / way 183122708',
        verifiedAt: '2026-08-20',
      ),
      'kultepe-kanis-karum': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q538605',
        verifiedAt: '2026-08-20',
      ),
      'eflatunpinar': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Wikimedia Commons geotag',
        sourceRef: 'Q844601 / 37.825347,31.674541',
        verifiedAt: '2026-08-20',
      ),
      'odunpazari-tarihi-evleri': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikimedia Commons geotag',
        sourceRef: 'Odunpazarı Evleri / 39.764839,30.521839',
        verifiedAt: '2026-08-20',
      ),
      'borcka-karagol': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Wikimedia Commons',
        sourceRef: 'Q6100677 / 41.385569,41.853939',
        verifiedAt: '2026-08-20',
      ),
      'sahinkaya-kanyonu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q61075807',
        verifiedAt: '2026-08-20',
      ),
      'cal-magarasi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q97209322',
        verifiedAt: '2026-08-20',
      ),
      'ahlat-selcuklu-mezarligi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q19610409',
        verifiedAt: '2026-08-20',
      ),
      'hosap-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + Wikimedia Commons geotag',
        sourceRef: 'Q1420248 / 38.316944,43.801667',
        verifiedAt: '2026-08-20',
      ),
      'muradiye-selalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q31190849',
        verifiedAt: '2026-08-20',
      ),
      'deyrulzafaran-manastiri': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikimedia Commons geotag',
        sourceRef: 'Mor Hananyo Monastery / 37.298952,40.791128',
        verifiedAt: '2026-08-20',
      ),
      'hasankeyf-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q131901864',
        verifiedAt: '2026-08-20',
      ),
      'on-gozlu-kopru': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q5273857',
        verifiedAt: '2026-08-20',
      ),
    };

bool isSpotCoordinateIndependentlyVerifiedBatch12(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch12.containsKey(spotId);
