import 'package:cloud_functions/cloud_functions.dart';

class VenueQualityService {
  static const labels = ['', 'TBT Öneriyor', 'TBT Seçkisi', 'TBT İmzası'];
  static const keys = ['quality', 'cleanliness', 'service', 'value', 'comfort'];
  static bool supports(String category) => ['dining', 'cafe', 'hotel'].contains(category);
  static Map<String, String> criteria(String category) => {
    'quality': category == 'hotel' ? 'Oda ve uyku kalitesi' : 'Lezzet ve ürün kalitesi',
    'cleanliness': 'Temizlik ve bakım',
    'service': 'Hizmet ve personel',
    'value': 'Fiyatına göre karşılık',
    'comfort': category == 'hotel' ? 'Sunulan olanaklar' : 'Ortam ve konfor',
  };
  static Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> data = const {}]) async {
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('venueQuality').call({'action': action, ...data});
    return Map<String, dynamic>.from(result.data as Map);
  }
  static String error(Object e) {
    if (e is FirebaseFunctionsException) {
      if (e.code == 'not-found') return 'Değerlendirme servisine şu anda ulaşılamıyor. Tekrar dene.';
      if (e.code == 'unauthenticated') return 'Değerlendirme için yeniden giriş yapmalısın.';
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') return 'Bağlantı kurulamadı. Yeniden dene.';
      return e.message ?? 'İşlem tamamlanamadı.';
    }
    return 'Bağlantı kurulamadı. Yeniden dene.';
  }
}
