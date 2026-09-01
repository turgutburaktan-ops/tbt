# TBT Google Play yayın kontrolü

## Teknik olarak hazırlandı

- Paket adı: `com.tbt.social`
- İlk mağaza sürümü: `1.0.0+1`
- Kamera donanımı zorunlu değil; kamerasız uyumlu cihazlar gereksiz yere elenmez.
- Android 13+ bildirim izni manifestte tanımlı.
- HTTP açık trafik kapalı ve yedekleme devre dışı.
- Üretim AAB'si yalnızca Play imza ve üretim reklam sırlarıyla oluşturulur.
- Debug/test reklam kimlikleri üretim AAB iş akışında gerçek kimliklerle değiştirilir.

## Play Console'da tamamlanacaklar

1. `PLAY_KEYSTORE_BASE64`, `PLAY_KEYSTORE_PASSWORD`, `PLAY_KEY_ALIAS`, `PLAY_KEY_PASSWORD`, `MAPS_API_KEY`, `ADMOB_ANDROID_APP_ID`, `ADMOB_NATIVE_ANDROID` ve `GOOGLE_SERVER_CLIENT_ID` GitHub secrets olarak girilmeli.
2. **Android Play Release** iş akışı çalıştırılıp oluşan `.aab` İç Test kanalına yüklenmeli.
3. Gizlilik politikası URL'si, Veri Güvenliği formu, reklam beyanı, içerik derecelendirmesi ve hesap silme URL'si Play Console'da doldurulmalı.
4. Konum, kamera, mikrofon, fotoğraf/video, bildirimler, kullanıcı içeriği, mesajlar, reklam kimliği ve Firebase/Google veri işleme beyanları uygulamadaki gerçek akışlarla aynı olmalı.
5. Gerçek cihazda hesap açma, telefon doğrulama, hesap silme, konum reddi, kamera reddi, reklam ve işletme etkinliği uçtan uca test edilmeli.
