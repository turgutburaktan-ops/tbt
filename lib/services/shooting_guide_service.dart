import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/photo_spot.dart';
import '../models/shooting_guide.dart';

class ShootingGuideService {
  ShootingGuideService._();

  static final ShootingGuideService instance = ShootingGuideService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String spotsCollection = 'photo_spots';
  static const String guidesCollection = 'shooting_guides';

  Future<ShootingGuide> loadForSpot(PhotoSpot spot) async {
    try {
      final spotDoc = await _firestore
          .collection(spotsCollection)
          .doc(spot.id)
          .get();
      final spotData = spotDoc.data();
      final embedded = spotData?['shootingGuide'];
      if (embedded is Map) {
        final guide = ShootingGuide.fromMap(
          spot.id,
          Map<String, dynamic>.from(embedded),
        );
        if (guide.hasRichGuide) return guide;
      }
    } catch (_) {}

    try {
      final guideDoc = await _firestore
          .collection(guidesCollection)
          .doc(spot.id)
          .get();
      final data = guideDoc.data();
      if (data != null) {
        final guide = ShootingGuide.fromMap(spot.id, data);
        if (guide.hasRichGuide) return guide;
      }
    } catch (_) {}

    return _fallbackFromSpot(spot);
  }

  ShootingGuide _fallbackFromSpot(PhotoSpot spot) {
    final isPortrait =
        spot.category.toLowerCase().contains('portre') ||
        spot.tags.any((tag) => tag.toLowerCase().contains('portre'));

    return ShootingGuide(
      spotId: spot.id,
      shootingPosition: spot.angle.trim().isNotEmpty ? spot.angle.trim() : 'Ana manzarayi gorecek guvenli bir noktadan baslayip birkac metre sag ve solu dene.',
      subjectPlacement: isPortrait
          ? 'Kisiyi kadrajin tam ortasina kilitlemek yerine ucte bir cizgilerinden birine yerlestir.'
          : 'Ana yapiyi veya manzarayi ucte bir kuralina gore konumlandir; on planda derinlik veren bir oge ara.',
      lightDirection: spot.bestTime.trim().isNotEmpty
          ? '${spot.bestTime.trim()} saatlerinde isigin ozneye yandan gelmesini hedefle; sert ters isikta pozlamayi koru.'
          : 'Altin saatte yandan gelen isigi tercih et; ogle saatlerinde golge detaylarini kontrol et.',
      portraitTip: isPortrait
          ? 'Arka plani sadelestir, ozne ile arka plan arasina mesafe koy ve mumkunse tele karakterli aci kullan.'
          : 'Insan ekleyeceksen olcek hissi verecek sekilde ana yapinin onunde kucuk bir siluet olarak kullan.',
      compositionTip: spot.description.trim().isNotEmpty
          ? 'Mekanin karakterini one cikar: ${spot.description.trim()}'
          : 'Simetri, yonlendiren cizgiler ve katmanli on plan alternatiflerini sirayla dene.',
      recommendedSettings:
          'Baslangic: ${spot.recommendedLens}. ISO 100-400, elde cekimde en az 1/125 sn; isiga gore EV ayarla.',
      accessibilityNote: spot.difficulty.trim().isNotEmpty
          ? 'Erisim/zorluk: ${spot.difficulty.trim()}. Cekim yaparken gecis yollarini kapatma ve guvenli zeminde kal.'
          : 'Cekim sirasinda guvenli zeminde kal ve gecis yollarini kapatma.',
      shotIdeas: const [
        'Genis aciyla mekani anlatan genel plan',
        'Dikey kadrajla sosyal medya odakli kompozisyon',
        'On planda obje kullanarak derinlikli kare',
      ],
    );
  }
}
