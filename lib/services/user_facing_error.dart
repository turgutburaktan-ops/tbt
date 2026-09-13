import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

/// Keep backend diagnostics out of user-facing messages.
String userFacingError(Object error) {
  if (error is PlatformException) {
    if ([
      'permission',
      'photo_access_denied',
      'camera_access_denied',
    ].contains(error.code))
      return 'Fotoğraf erişim iznini Ayarlar’dan açıp tekrar dene.';
    if (error.code == 'save_failed')
      return 'Galeriye kaydedilemedi. Depolama alanını ve fotoğraf izinlerini kontrol et.';
  }
  final raw = error.toString();
  final code = error is FirebaseException ? error.code : '';
  if (error is SocketException ||
      code == 'network-request-failed' ||
      raw.toLowerCase().contains('client is offline')) {
    return 'İnternet bağlantısı yok. Bağlantını kontrol edip tekrar dene.';
  }
  if (error is TimeoutException || code == 'deadline-exceeded') {
    return 'İşlem zaman aşımına uğradı. Bağlantını kontrol edip tekrar dene.';
  }
  if (code == 'unavailable') {
    return 'Hizmete şu an ulaşılamıyor. Bağlantını kontrol edip tekrar dene.';
  }
  if (code == 'permission-denied' || code == 'unauthorized') {
    return 'Bu işlem için erişim iznin bulunmuyor.';
  }
  if (code == 'unauthenticated' || code == 'user-token-expired') {
    return 'Oturumun sona ermiş. Lütfen yeniden giriş yap.';
  }
  if (code == 'not-found' || code == 'object-not-found') {
    return 'İstenen içerik bulunamadı. Silinmiş veya kaldırılmış olabilir.';
  }
  if (code == 'resource-exhausted' || code == 'too-many-requests') {
    return 'Çok fazla işlem yapıldı. Biraz bekleyip tekrar dene.';
  }
  if (error is FirebaseException) {
    return 'İşlem tamamlanamadı. Lütfen tekrar dene.';
  }
  final message = raw.replaceFirst('Exception: ', '');
  // Existing application validation messages are already Turkish.
  if (RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(message) &&
      !message.contains('Exception') &&
      !message.contains('[')) {
    return message;
  }
  return 'İşlem tamamlanamadı. Lütfen tekrar dene.';
}
