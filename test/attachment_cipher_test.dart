import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/security/attachment_cipher.dart';

void main() {
  test('media authenticates path, bytes and key; random encryption differs on each upload', () async {
    final plain = Uint8List.fromList([255, 216, 1, 2, 3, 255, 217]);
    final first = await AttachmentCipher.seal(
      plain,
      'e2ee_chat/t/a/m/payload.bin',
    );
    final second = await AttachmentCipher.seal(
      plain,
      'e2ee_chat/t/a/m/payload.bin',
    );
    expect(first.bytes, isNot(second.bytes));
    expect(first.key, isNot(second.key));
    expect(
      await AttachmentCipher.open(
        first.bytes,
        first.key,
        'e2ee_chat/t/a/m/payload.bin',
        maxBytes: 15 * 1024 * 1024,
      ),
      plain,
    );
    await expectLater(
      AttachmentCipher.open(
        first.bytes,
        first.key,
        'other-thread',
        maxBytes: 100,
      ),
      throwsA(anything),
    );
    await expectLater(
      AttachmentCipher.open(
        first.bytes,
        second.key,
        'e2ee_chat/t/a/m/payload.bin',
        maxBytes: 100,
      ),
      throwsA(anything),
    );
    final tampered = Uint8List.fromList(first.bytes);
    tampered[13] ^= 1;
    await expectLater(
      AttachmentCipher.open(
        tampered,
        first.key,
        'e2ee_chat/t/a/m/payload.bin',
        maxBytes: 100,
      ),
      throwsA(anything),
    );
    await expectLater(
      AttachmentCipher.open(
        first.bytes,
        first.key,
        'e2ee_chat/t/a/m/payload.bin',
        maxBytes: 1,
      ),
      throwsA(anything),
    );
  });
}
