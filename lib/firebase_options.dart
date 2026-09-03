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

  // CI gerektiğinde bu değerleri --dart-define ile değiştirebilir. Varsayılanlar
  // Firebase'de com.tbt.social için kayıtlı üretim iOS uygulamasına aittir.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: 'AIzaSyD4K_4viTADCMtYfC0xcOHGhCqh-6WibPs',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: '1:330568532415:ios:09e96cf59344065641a10a',
    ),
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
