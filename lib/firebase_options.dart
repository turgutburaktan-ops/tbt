import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppFirebaseOptions {
  AppFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBDoKy5YMP5-6UJqotfuUA7a74H-x-5miQ',
    appId: '1:330568532415:android:425699d143ec3eb041a10a',
    messagingSenderId: '330568532415',
    projectId: 'en-iyi-cekim-noktasi',
    storageBucket: 'en-iyi-cekim-noktasi.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web Firebase ayarları henüz tanımlı değil.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
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
