import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptedAttachment {
  final Uint8List bytes;
  final String key;
  EncryptedAttachment(this.bytes, this.key);
}

class AttachmentCipher {
  static Future<EncryptedAttachment> seal(
    Uint8List plain,
    String context,
  ) async {
    if (plain.isEmpty) throw StateError('Boş medya şifrelenemez.');
    final cipher = AesGcm.with256bits(),
        key = await AesGcm.with256bits().newSecretKey();
    final sealed = await cipher.encrypt(
      plain,
      secretKey: key,
      aad: utf8.encode(context),
    );
    return EncryptedAttachment(
      Uint8List.fromList(sealed.concatenation()),
      base64Encode(await key.extractBytes()),
    );
  }

  static Future<Uint8List> open(
    Uint8List bytes,
    String key,
    String context, {
    required int maxBytes,
  }) async {
    if (bytes.length <= 28 || bytes.length > maxBytes + 28)
      throw StateError('Şifreli medya boyutu geçersiz.');
    final decodedKey = base64Decode(key);
    if (decodedKey.length != 32) throw StateError('Medya anahtarı geçersiz.');
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16),
        secretKey: SecretKey(decodedKey),
        aad: utf8.encode(context),
      );
      try {
        return Uint8List.fromList(clear);
      } finally {
        clear.fillRange(0, clear.length, 0);
      }
    } finally {
      decodedKey.fillRange(0, decodedKey.length, 0);
    }
  }
}
