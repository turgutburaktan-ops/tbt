import 'spot_coordinate_verification_registry.dart';

/// Beşinci doğrulanmış gezi grubu için bağımsız koordinat kanıtları.
const verifiedSpotCoordinateEvidenceBatch5 =
    <String, SpotCoordinateVerificationEvidence>{
  'edirne-selimiye': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q184534',
    verifiedAt: '2026-08-20',
  ),
  'bursa-ulu-camii': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q32339',
    verifiedAt: '2026-08-20',
  ),
  'cumalikizik': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata + UNESCO',
    sourceRef: 'Q1897419 / UNESCO 1452-008',
    verifiedAt: '2026-08-20',
  ),
  'divrigi-ulu-camii': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata + UNESCO',
    sourceRef: 'Q581641 / UNESCO 358',
    verifiedAt: '2026-08-20',
  ),
  'varda-koprusu': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q1522793',
    verifiedAt: '2026-08-20',
  ),
  'malabadi-koprusu': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q3397053',
    verifiedAt: '2026-08-20',
  ),
  'amasya-kral-kaya-mezarlari': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q6022363 / Q64735225',
    verifiedAt: '2026-08-20',
  ),
  'sinop-tarihi-cezaevi': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q7524921',
    verifiedAt: '2026-08-20',
  ),
  'izmir-saat': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q3696052',
    verifiedAt: '2026-08-20',
  ),
  'canakkale-sehitler-abidesi': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q8077504',
    verifiedAt: '2026-08-20',
  ),
  'bozcaada-kalesi': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q6050068',
    verifiedAt: '2026-08-20',
  ),
  'diyarbakir-ulu-camii': SpotCoordinateVerificationEvidence(
    sourceName: 'T.C. Kültür ve Turizm Bakanlığı + Wikimedia Commons GPS',
    sourceRef: 'Kültür Portalı Diyarbakır Ulu Cami / Diyarbakir_Ulu_Cami_2022.jpg',
    verifiedAt: '2026-08-20',
  ),
};

bool isSpotCoordinateIndependentlyVerifiedBatch5(String spotId) =>
    verifiedSpotCoordinateEvidenceBatch5.containsKey(spotId);
