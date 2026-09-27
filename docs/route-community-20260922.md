# Rota topluluk işleri — 22 Eylül 2026

Önceki erişim çalışmasının (PR #108, remote ef819e3ab4d231f1f3a9b563470caf03de762f11) üzerine hazırlanmıştır.

## Uygulanan kapsam

- Rota detayında özel durağa dokunup Gezi’ye önerme: hem `map:` hem eski `custom_` durakları desteklenir. Yer adı, şehir, açıklama ve koordinatlar forma taşınır; kullanıcı fotoğraf ve neden görülmeli bilgisini ekler.
- Rota üyesi olma ve durağın gerçekten rotada bulunması sunucuda doğrulanır. Mevcut katalog ve işletme durakları bu akıştan gönderilemez.
- Kullanıcı/rota/durak için aynı öneri kimliği kullanılır. Yinelenen gönderimler ikinci öneri oluşturmaz; ret sonrasında düzeltme gönderilebilir. Önerinin durumu ve ret gerekçesi durak detayında gösterilir.
- Mevcut yönetici paneli rota kaynağını ve benzer kayıtları gösterir. Şehir içindeki mükerrer kontrolü ilk 100 kayıtla sınırlı değildir; cityKey olmayan eski şehir kayıtları da kontrol edilir.
- Onay ve yer oluşturma tek transaction içindedir. Şehir bazlı kilit, eşzamanlı onayların aynı yeri iki defa eklemesini engeller. Mevcut onaylı öneri tetikleyicisi 30 Kaşif puanı verir; mükerrer/ret puan vermez.
- Yeni rotalarda `discoverPublished: false`. Sahip, herkese açık rotayı detay ekranında ayrı bir onayla Keşfet’te yayınlar veya listeden kaldırır. Katılım koşulları bağımsız kalır. Görünürlüğü daraltmak yayın durumunu da kapatır.
- Eski, bu alanı taşımayan herkese açık rotalar Keşfet’te görünmeye devam eder. Önceden mevcut takipçilere özel keşif akışı korunur. Radar, yayınlanma tercihinden bağımsız mevcut herkese açık rota sorgusunu kullanır.
- Keşfet kartında hazırlayan, mevcut rota bilgileri ve bisiklet/yürüyüş için varsa tahmini zorluk gösterilir. Kaydet/Kaydedildi ile favoriye ekleme ve çıkarma vardır.
- Kopyalama önce güncel erişimi kontrol eder. Yeni kopya özel, tarihsiz, katılımı kapalı ve Keşfet yayını kapalıdır. Geometri ve zorluk korunur; eski etkinlik/katılımcı/davetli/albüm bilgileri taşınmaz.
- Yayın puanı mevcut aynı ledger anahtarını kullanır; yayından kaldırıp yeniden yayınlamak ek puan sağlamaz.

## Doğrulama

Geçti:

- 6 sunucu işleyici testi (bellek içi Firestore test ikiziyle).
- 5 mevcut rol/puan sistemi birim testi.
- Gerçek Dart SDK ile saf rota kopyalama gizlilik ve durak uygunluğu kontrolleri.
- Değişen Dart dosyaları biçimlendirildi; JavaScript söz dizimi ve `git diff --check` başarılı.

Henüz çalışmadı:

- Flutter analizi ve widget/regresyon testleri.
- Firestore emülatöründe erişim, yayınlama ve gerçek transaction testleri.

`.github/workflows/route_community_check.yml` bu kontroller için hazır. GitHub bağlantısı HTTP 400 `Invalid MCP request metadata` hatası verdiğinden uzak dal/PR oluşturulamadı ve Actions başlatılamadı. Bellek içi test, gerçek Firestore izolasyon testinin yerine geçmez.

## Yayın bağımlılıkları

Üretime dağıtılmadı. Uygulama ile birlikte Firestore kuralları, `submitSpotSuggestion`, `listPendingSpotSuggestions`, `reviewSpotSuggestion`, güncellenen `awardPublishedRouteReputation` ve yeni `awardDiscoveredRouteReputation` dağıtılmalıdır. Mevcut `awardApprovedSpotReputation` aktif kalmalıdır. Önce PR #108 bağımlılığı ve bu dalın bütünleşik testleri doğrulanmalıdır.
