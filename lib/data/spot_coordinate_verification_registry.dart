class SpotCoordinateVerificationEvidence {
  final String sourceName;
  final String sourceRef;
  final String verifiedAt;

  const SpotCoordinateVerificationEvidence({
    required this.sourceName,
    required this.sourceRef,
    required this.verifiedAt,
  });
}

/// Tek tek bağımsız kaynakla çapraz kontrolü tamamlanan koordinatlar.
/// Yeni kayıt ancak gerçek yer adı + şehir + koordinat eşleşmesi kontrol
/// edildikten sonra bu listeye alınmalı.
const verifiedSpotCoordinateEvidence =
    <String, SpotCoordinateVerificationEvidence>{
  'tr-istanbul-galata81': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q91274',
    verifiedAt: '2026-08-19',
  ),
  'tr-ankara-anitkabir81': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata',
    sourceRef: 'Q615404',
    verifiedAt: '2026-08-19',
  ),
  'tr-elazig-harput81': SpotCoordinateVerificationEvidence(
    sourceName: 'Wikidata + Getty TGN',
    sourceRef: 'Q6017381 / TGN 7691814',
    verifiedAt: '2026-08-19',
  ),
};

bool isSpotCoordinateIndependentlyVerified(String spotId) =>
    verifiedSpotCoordinateEvidence.containsKey(spotId);
