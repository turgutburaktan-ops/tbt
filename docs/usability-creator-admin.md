# TBT kullanım ve Creator yönetimi

- Profilde Aktif kuponlar / Aktif rezervasyonlar; geçmiş kayıtlar Ayarlar → Geçmiş altında korunur.
- Mesaj düzenleme yazma alanında; Vazgeç önceki taslağı geri getirir. İsim/fotoğraf profili açar.
- Ana akış ortak ses anahtarı, ana sayfaya dönüşte açık ses. Reels ayrı ortak tercih.
- Creator yönetimi: hesaplar, kişisel davet oluşturma, süre/kullanım sınırı, daveti kapatma, kullananlar, getirdiği kullanıcılar ve içerik istatistikleri.
- Görüntülenme/profil geçişleri 7/30/90 gün veya tüm zamanlar; günlük ölçüm başlangıcı gösterilir. Beğeni, yorum, kaydetme, yeniden paylaşım ve aktif hikâyeler güncel sayılardır. En başarılı içerikler tüm içeriklerin toplam görüntülenmesine göre sıralanır.
- TBT duyurusuna JPEG fotoğraf seçme, önizleme ve gönderimden önce kaldırma. Fotoğraf bildirim merkezi ve duyuru detayında görünür; pazarlama izni korunur.
- Önceki Creator Merkezi, rehber/gönderi, hikâyede paylaşım, yeniden paylaşım ve sohbet arka planı çalışmaları dahildir.

## Yenilenen pencereler

Gri/mor hazır pencereler ortak gece mavisi kaydırılabilir forma taşındı. Mesaj düzenleme artık pencere açmaz. Günlük hedef penceresi önceki gece mavisi çalışmasından dahil edildi. Tarih/saat seçicileri de gece mavisi.

| Dosya | Form/onay sayısı |
| --- | ---: |
| `lib/screens/admin_broadcast_screen.dart` | 1 |
| `lib/screens/admin_business_premium_screen.dart` | 1 |
| `lib/screens/admin_business_sandbox_screen.dart` | 2 |
| `lib/screens/admin_businesses_v2_screen.dart` | 3 |
| `lib/screens/admin_dashboard_screen.dart` | 2 |
| `lib/screens/admin_published_spots_screen.dart` | 1 |
| `lib/screens/admin_spot_submissions_screen.dart` | 1 |
| `lib/screens/business_content_manager_screen.dart` | 1 |
| `lib/screens/business_hours_screen.dart` | 0 |
| `lib/screens/business_hub_screen.dart` | 1 |
| `lib/screens/business_profile_screen.dart` | 1 |
| `lib/screens/business_reservation_screen.dart` | 0 |
| `lib/screens/community_profile_screen.dart` | 0 |
| `lib/screens/creator_admin_screen.dart` | 3 |
| `lib/screens/creator_center_screen.dart` | 1 |
| `lib/screens/event_create_screen_v2.dart` | 0 |
| `lib/screens/feed_screen.dart` | 1 |
| `lib/screens/login_screen.dart` | 1 |
| `lib/screens/map_screen.dart` | 1 |
| `lib/screens/music_detail_screen.dart` | 1 |
| `lib/screens/my_posts_screen.dart` | 1 |
| `lib/screens/post_detail_screen.dart` | 1 |
| `lib/screens/profile_page_v2.dart` | 1 |
| `lib/screens/public_travel_plans_screen.dart` | 1 |
| `lib/screens/route_planner_screen.dart` | 2 |
| `lib/screens/safety_privacy_center_screen.dart` | 2 |
| `lib/screens/settings_screen.dart` | 4 |
| `lib/screens/smart_plan_screen.dart` | 0 |
| `lib/screens/social_events_screen.dart` | 1 |
| `lib/screens/spot_suggestion_screen.dart` | 1 |
| `lib/screens/story_archive_screen.dart` | 1 |
| `lib/screens/travel_plan_detail_screen.dart` | 2 |
| `lib/screens/travel_plans_screen.dart` | 1 |
| `lib/widgets/chat_collaboration_controls.dart` | 1 |
| `lib/widgets/event_hub_panel.dart` | 1 |
| `lib/widgets/reservation_controls.dart` | 2 |
| `lib/widgets/spot_experience_sections.dart` | 0 |
| `lib/widgets/story_strip.dart` | 1 |
| `lib/widgets/user_safety_actions.dart` | 2 |

## Yayına alma ve cihaz kontrolü

Android hızlı yanıt destekleyen yeni istemciler eylemli bildirim alır; eski sürümlerin standart bildirimi korunur. iOS native metin yanıtı kullanır. Sunucu oturumu, bildirimin sahibini, üyeliği, engelleri ve hesap durumunu doğrular. Bildirim başına tek mesaj kimliği yeniden denemede çift gönderimi önler.

Mobil sürümle birlikte güncellenen Functions, Firestore ve Storage kuralları yayımlanmalıdır. Android host üretildikten sonra `tool/configure_notifications.py android` çalışır; iOS paylaşım kurulumuna bildirim kurulumu dahildir.

Derleme kontrolü dışında fiziksel Android/iOS cihazda arka planda ve uygulama kapalıyken yanıt, oturum değişikliği ve çevrimdışı yeniden deneme kontrolü gerekir. Bu kod değişikliği gerçek kullanıcılara duyuru göndermez.

Functions yayını mevcut Deploy Firebase Functions iş akışındaki `usability-creator` kapsamıyla veya `[usability-creator]` commit işaretiyle yapılır. Bu kapsam yalnız ilgili işlevleri günceller. Gerekli Creator indeksleri eklemeli oluşturulur; mevcut indeksler silinmez. Kurallar iş akışı Storage kurallarını da yayımlar.
