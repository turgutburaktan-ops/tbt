import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum ChatPhotoMode { once, replay, keep }

Uint8List preparePrivatePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Fotoğraf okunamadı.');
  var image = img.bakeOrientation(decoded);
  if (image.width > 1280 || image.height > 1280) {
    image = img.copyResize(image,
      width: image.width >= image.height ? 1280 : null,
      height: image.height > image.width ? 1280 : null);
  }
  // Fresh pixels strip EXIF, GPS and the original thumbnail.
  image = img.Image.fromBytes(width: image.width, height: image.height,
    bytes: image.getBytes(order: img.ChannelOrder.rgb).buffer, numChannels: 3);
  for (var quality = 85; quality >= 35; quality -= 10) {
    final result = img.encodeJpg(image, quality: quality);
    if (result.length <= 512 * 1024) return result;
  }
  throw Exception('Fotoğraf hazırlanamadı. Daha küçük bir fotoğraf seç.');
}

class PrivatePhotoService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  static Future<Map<String, dynamic>> call(Map<String, dynamic> data) async {
    final result = await _functions.httpsCallable('chatPrivatePhoto',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 35))).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<void> send(String threadId, Uint8List bytes, ChatPhotoMode mode) async {
    final prepared = await compute(preparePrivatePhoto, bytes);
    final messageId = FirebaseFirestore.instance.collection('chat_threads').doc().id;
    await call({'action': 'send', 'threadId': threadId, 'messageId': messageId,
      'mode': mode.name, 'bytes': base64Encode(prepared)});
    prepared.fillRange(0, prepared.length, 0);
  }
}
