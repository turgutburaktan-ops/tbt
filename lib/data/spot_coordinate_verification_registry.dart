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
      'ayasofya': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q12506',
        verifiedAt: '2026-08-19',
      ),
      'kiz-kulesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q848397',
        verifiedAt: '2026-08-19',
      ),
      'galata': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q91274',
        verifiedAt: '2026-08-19',
      ),
      'anitkabir': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q615404',
        verifiedAt: '2026-08-19',
      ),
      'ankara-kale': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q206225',
        verifiedAt: '2026-08-19',
      ),
      'safranbolu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q64705254',
        verifiedAt: '2026-08-19',
      ),
      'sumela': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + official site',
        sourceRef: 'Q1419157 / sumela.gov.tr',
        verifiedAt: '2026-08-19',
      ),
      'assos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q108513185',
        verifiedAt: '2026-08-19',
      ),
      'bodrum-kale': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1113602',
        verifiedAt: '2026-08-19',
      ),
      'efes': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + UNESCO',
        sourceRef: 'Q47611 / UNESCO 1018',
        verifiedAt: '2026-08-19',
      ),
      'pamukkale': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q105893254',
        verifiedAt: '2026-08-19',
      ),
      'nemrut': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q207917',
        verifiedAt: '2026-08-19',
      ),
      'salda': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q3234128',
        verifiedAt: '2026-08-19',
      ),
      'konya-mevlana': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q902957',
        verifiedAt: '2026-08-19',
      ),
      'goreme-acik-hava': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + official museum site',
        sourceRef: 'Q115453100 / muze.gov.tr',
        verifiedAt: '2026-08-19',
      ),
      'harput-kalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6017381',
        verifiedAt: '2026-08-19',
      ),

      // İkinci doğrulanmış gezilecek yer grubu.
      'sultanahmet-camii': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q80541',
        verifiedAt: '2026-08-19',
      ),
      'yerebatan-sarnici': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q216511',
        verifiedAt: '2026-08-19',
      ),
      'topkapi-sarayi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q170495',
        verifiedAt: '2026-08-19',
      ),
      'troya': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q16920985',
        verifiedAt: '2026-08-19',
      ),
      'bergama-akropol': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q69567912',
        verifiedAt: '2026-08-19',
      ),
      'aphrodisias': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q618495',
        verifiedAt: '2026-08-19',
      ),
      'gobeklitepe': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q214944',
        verifiedAt: '2026-08-19',
      ),
      'ani-oren-yeri': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q546010',
        verifiedAt: '2026-08-19',
      ),
      'ishak-pasa-sarayi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1501534',
        verifiedAt: '2026-08-19',
      ),
      'akdamar-kilisesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1281985',
        verifiedAt: '2026-08-19',
      ),
      'mardin-tarihi-merkez': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata (Mardin Ulu Camii anchor)',
        sourceRef: 'Q65220334',
        verifiedAt: '2026-08-19',
      ),
      'hattusa': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q181007',
        verifiedAt: '2026-08-19',
      ),

      // Üçüncü doğrulanmış grup: doğa ve manzara rotaları.
      'uzungol': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1095336',
        verifiedAt: '2026-08-19',
      ),
      'rize-ayder': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q2582947',
        verifiedAt: '2026-08-19',
      ),
      'oludeniz': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata (Ölüdeniz-Kıdrak Nature Park)',
        sourceRef: 'Q61075941',
        verifiedAt: '2026-08-19',
      ),
      'kelebekler-vadisi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6098733',
        verifiedAt: '2026-08-19',
      ),
      'saklikent-kanyonu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q79753',
        verifiedAt: '2026-08-19',
      ),
      'ihlara-vadisi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q22343387',
        verifiedAt: '2026-08-19',
      ),
      'yedigoller-milli-parki': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q6981621',
        verifiedAt: '2026-08-19',
      ),
      'abant-golu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata (Lake Abant National Park)',
        sourceRef: 'Q34888863',
        verifiedAt: '2026-08-19',
      ),
      'antalya-duden': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata (Lower Düden Waterfalls)',
        sourceRef: 'Q72177820',
        verifiedAt: '2026-08-19',
      ),
      'manavgat-selalesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q2574216',
        verifiedAt: '2026-08-19',
      ),
      'cennet-cehennem': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q474939',
        verifiedAt: '2026-08-19',
      ),
      'egirdir-golu': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q1334148',
        verifiedAt: '2026-08-19',
      ),

      // Dördüncü doğrulanmış grup: antik kent ve kültür rotaları.
      'aspendos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q16697381',
        verifiedAt: '2026-08-20',
      ),
      'perge': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q719815',
        verifiedAt: '2026-08-20',
      ),
      'patara': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q233121',
        verifiedAt: '2026-08-20',
      ),
      'xanthos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q464936',
        verifiedAt: '2026-08-20',
      ),
      'letoon': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata / UNESCO grouping',
        sourceRef: 'Q703480 / Q16912661',
        verifiedAt: '2026-08-20',
      ),
      'myra': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q652024',
        verifiedAt: '2026-08-20',
      ),
      'kaunos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata + UNESCO tentative list',
        sourceRef: 'Q608095 / 5906',
        verifiedAt: '2026-08-20',
      ),
      'knidos': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q690575',
        verifiedAt: '2026-08-20',
      ),
      'balikligol': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q805908',
        verifiedAt: '2026-08-20',
      ),
      'harran': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q199547',
        verifiedAt: '2026-08-20',
      ),
      'zeugma-muzesi': SpotCoordinateVerificationEvidence(
        sourceName: 'Wikidata',
        sourceRef: 'Q196982',
        verifiedAt: '2026-08-20',
      ),
      'dara-antik-kenti': SpotCoordinateVerificationEvidence(
        sourceName: 'T.C. Kültür ve Turizm Bakanlığı Müze + Wikidata',
        sourceRef: 'muze.gov.tr DRA01 / Q585145',
        verifiedAt: '2026-08-20',
      ),

      // Eski 81-il genişleme kayıtlarının doğrulanmış eşleri korunuyor.
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
