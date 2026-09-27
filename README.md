# En İyi Çekim Noktası — Flutter MVP

Bu proje gerçek cihaz kamerası + GPS + Google Maps + AI analiz akışını başlatan bir MVP'dir.

## Kurulum

1. Flutter SDK kur.
2. Projeyi aç.
3. `flutter pub get`
4. Android Studio/VS Code ile Android cihaz veya emulator seç.
5. `flutter run`

## Google Maps

Android için Google Maps API anahtarını kendi Android projesine eklemeden harita ekranı çalışmayacaktır.

`android/app/src/main/AndroidManifest.xml` içine `<application>` altında:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

API anahtarını git reposuna commit etme.

## AI

`lib/services/ai_service.dart` içindeki endpoint demo amaçlıdır.

Gerçek AI kullanmak için:
- Güvenli bir backend oluştur.
- Fotoğrafı multipart olarak backend'e gönder.
- Backend AI sağlayıcısına isteği yapsın.
- Mobil uygulamaya sadece analiz sonucunu döndürsün.

Mobil uygulamaya AI API key koyma.

## MVP'de çalışan akış

Ana ekran → Kamera → Gerçek cihaz kamerası → GPS → Fotoğraf → AI analiz ekranı.

AI servisinde şimdilik gerçek API yerine demo sonuç dönüyor; backend endpoint bağlandığında gerçek analiz yapılabilir.
