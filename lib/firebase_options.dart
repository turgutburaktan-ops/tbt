import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppFirebaseOptions {
  AppFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBDoKy5YMP5-6UJqotfuUA7a74H-x-5miQ',
    appId: '1:330568532415:android:bf2ffa0b4d9210ed41a10a',
    messagingSenderId: '330568532415',
    projectId: 'en-iyi-cekim-noktasi',
    storageBucket: 'en-iyi-cekim-noktasi.firebasestorage.app',
  );

  // iOS Firebase uygulaması oluşturulduktan sonra bu iki değer CI/Store
  // derlemesine --dart-define ile verilir. Proje/sender/bucket aynı Firebase
  // projesini kullanır; iOS appId ise platforma özeldir.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    messagingSenderId: '330568532415',
    projectId: 'en-iyi-cekim-noktasi',
    storageBucket: 'en-iyi-cekim-noktasi.firebasestorage.app',
    iosBundleId: String.fromEnvironment(
      'IOS_BUNDLE_ID',
      defaultValue: 'com.tbt.social',
    ),
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web Firebase ayarları henüz tanımlı değil.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        if (ios.apiKey.isEmpty || ios.appId.isEmpty) {
          throw UnsupportedError(
            'iOS Firebase ayarları eksik. FIREBASE_IOS_API_KEY ve FIREBASE_IOS_APP_ID tanımlanmalı.',
          );
        }
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Bu platform için Firebase ayarları henüz tanımlı değil.',
        );
    }
  }
}
