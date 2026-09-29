# Uçtan uca şifreleme: yerel uygulama

Durum: Kod yerelde hazırlandı. Sunucu, kurallar ve uygulama yayınlanmadı. Üretimde E2EE etkin olduğu iddia edilmez. Güvenlik sürüm kapısı hâlâ beklemede.

## Kapsam ve tasarım

- Birebir/grup, rota ve etkinlik sohbetlerinde yeni metin, yanıt/alıntı, konum, paylaşım, anket içeriği ve medya anahtarları alıcı başına Signal Protocol zarfı içinde taşınır. Mesaj düzenleme de şifrelenir.
- Fotoğraf, ses ve video AES-256-GCM ile rastgele anahtarla cihazda şifrelenir. Nesne yolu doğrulanmış ek veridir. Firebase Storage yalnız şifreli baytları alır. Anahtar yalnız Signal zarfının içindedir.
- Tek gösterim fotoğraf sunucusu da şifreli bayt/zarf saklar; mevcut süre ve görüntüleme sayacı korunur. Alıcının değiştirilmiş uygulamayla gördüğü içeriği kopyalamasını kriptografi engelleyemez.
- Özel kimlik, ön anahtarlar, ratchet durumu ve yerel mesaj geçmişi AES-GCM kasasında atomik kaydedilir. Ana anahtar OS güvenli deposunda tutulur. iOS anahtarı bu cihaza bağlı ve kilit açıkken erişilebilirdir. Android yedekleme manifestte kapalıdır.
- Sunucuya yalnız açık anahtarlar gönderilir. İlk kimlik yerelde sabitlenir (TOFU); sonraki farklı kimlik reddedilir. Sohbet ekranındaki güvenlik kodu iki kullanıcı tarafından güvenilir ayrı bir kanaldan karşılaştırılmalıdır. İlk temasta kötü niyetli anahtar dizinine karşı otomatik kimlik garantisi yoktur.
- Sunucu üyeliği yeniden denetler, tam alıcı listesini zorunlu tutar ve gönderimi tek işlemde kaydeder. Sunucu mesaj özetleri ve bildirimler genel “Şifreli mesaj” metnidir. Şifreli moda geçmiş sohbette eski açık metin gönderme/düzenleme/hızlı yanıt yolları reddedilir.
- Bildirim hızlı yanıtı uygulamayı öne getirip ana isolate içinde cihazda şifrelenir; arka plan isolate ratchet durumunu değiştirmez. Anahtar erişilemiyorsa açık metne dönmez.

## Bilinen sınırlar ve yayın önkoşulları

- Hesap başına tek cihaz kimliği vardır. Cihaz aktarımı, anahtar kurtarma/sıfırlama ve çoklu cihaz henüz uygulanmadı. Uygulama verisi silinirse geçmiş ve gönderim erişimi kaybolabilir; sunucu kimliğini otomatik değiştirmek özellikle engellenir.
- Eski mesaj ve medyalar geriye dönük şifrelenmez. Albüme açıkça eklenen rota medyası ayrı erişim kontrollü paylaşım olarak kalır; E2EE değildir. Şifreli medya anahtarı albüme yazılmaz.
- Katılımcı kimlikleri, zamanlar, mesaj türü/boyutu, anket seçenek sayısı/oyları ve tepkiler sunucuya görünür. Cihaz ele geçirilmesi, ekran görüntüsü ve alıcının paylaşması kapsam dışıdır.
- Tüm alıcıların bu sürümle anahtar kaydetmesi gerekir; eksikse gönderim engellenir. En fazla 50 katılımcı desteklenir. Yeni üyeler eski zarfları açamaz.
- Kütüphane `libsignal_protocol_dart 0.8.2` kullanılır; bu entegrasyonun bağımsız kriptografik denetimi yapılmadı. GPL-3.0 bağımlılık lisansı dağıtım öncesi değerlendirilmelidir.
- Gerçek Android/iOS üzerinde güvenli depo, arka plan yanıtı, kilitli cihaz, eşzamanlı/çevrimdışı teslim, güncelleme, veri kaybı ve hesap değiştirme testleri gerekir. iOS host projesi bu depoda bulunmuyor; native yapılandırma ve güvenli depo yetkileri ayrıca doğrulanmalıdır.
- Anahtar yenileme ve ön anahtar havuzu ikmali henüz yoktur. 100 tek kullanımlık ön anahtar tükenince kütüphanenin imzalı ön anahtar akışı kullanılır. Var olan oturumlar yeni ön anahtar tüketmez.
- Yerel geçmiş ve çıkış kuyruğu kasada tutulur; saklama/temizleme politikası ve büyük geçmiş performansı yayın öncesi tamamlanmalıdır. Oynatıcıların geçici açık medya dosyaları normal kapanışta silinir; çökme sonrası temizlik ayrıca doğrulanmalıdır.

## Doğrulama

- `test/signal_engine_test.dart`: gerçek kütüphaneyle metin/yanıt, durum kaydetme-yükleme, bozulma, farklı sohbet/alıcı, tekrar gönderim, kimlik değişimi ve grup üyeliği testleri.
- `test/attachment_cipher_test.dart`: rastgele şifreleme, açma, yanlış yol/anahtar, bozulma ve boyut sınırı.
- `functions/test/e2ee_chat.test.js`: şema, kimlik sabitleme, ön anahtar, üyelik, idempotans, düzenleme, anket ve eski açık metin yolları.
- `test/e2ee_rules.cjs`: kimlik dizini erişimi, açık metne geri düşme, şifreli nesne erişimi ve değiştirilemezlik.
- `test/private_photo_backend.cjs`: şifreli tek gösterim fotoğraf dahil sunucu akışı.

Çalıştırma sonuçları yerel doğrulamayı gösterir; üretim veya gerçek cihaz doğrulaması yerine geçmez. Diğer açık sürüm engelleri `tool/security_release_readiness.json` içinde korunur.

### 28 Eylül 2026 yerel sonuçlar

- Flutter şifreleme çekirdeği ve medya: **5/5 geçti**.
- Mevcut sohbet erişimi, görünüm, özel medya, özel fotoğraf, rota sohbeti ve kaydırarak yanıt regresyonu: **16/16 geçti**.
- Fonksiyonlar ve güvenilir bildirim/özel medya testleri: **135/135 geçti**.
- Firestore/Storage emülatörü: **41 geçti, 0 başarısız, 2 atlandı**. Atlanan kontroller mevcut özel iletişim verileri ve dondurulmuş içerik okumalarıdır; kapatıldığı iddia edilmez.
- Tek gösterim fotoğraf emülatörü: **10/10 geçti**; şifreli içerik ve dondurulmuş hesap koruması dahil.
- `flutter build bundle --debug --no-pub`: **başarılı**. Bu bir Dart/Flutter debug bundle derlemesidir; APK/IPA veya mağaza dağıtımı değildir.
- `flutter analyze --no-pub`: **derleme hatası yok**; depoda lint/uyarılar mevcut, temiz analiz sonucu iddia edilmez.

Hiçbir uzak git push, Functions/Rules deploy veya mağaza yayını yapılmadı.
