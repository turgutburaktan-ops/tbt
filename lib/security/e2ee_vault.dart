import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'signal_engine.dart';

// A device-only master key protects the entire ratchet transaction, including
// the local message cache. Persist before returning anything to the network/UI.
class E2eeVault {
  static Future<void> _tail = Future.value();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  static Future<T> transaction<T>(
    String uid,
    Future<T> Function(SignalState) operation,
  ) {
    final result = _tail.then((_) => _run(uid, operation));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<T> _run<T>(
    String uid,
    Future<T> Function(SignalState) operation,
  ) async {
    final id = sha256.convert(utf8.encode(uid)).toString();
    final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/tbt_e2ee',
    );
    await root.create(recursive: true);
    final lock = await File('${root.path}/$id.lock')
        .open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    try {
      final file = File('${root.path}/$id.vault'),
          cipher = AesGcm.with256bits();
      var encodedKey = await _storage.read(key: 'tbt.e2ee.master.$id');
      if (encodedKey == null) {
        if (await file.exists())
          throw StateError('Bu cihazın şifreleme anahtarı bulunamadı.');
        encodedKey = base64Encode(
          await (await cipher.newSecretKey()).extractBytes(),
        );
        await _storage.write(key: 'tbt.e2ee.master.$id', value: encodedKey);
      }
      final key = SecretKey(base64Decode(encodedKey)),
          aad = utf8.encode('tbt-vault-v1:$uid');
      final SignalState state;
      if (await file.exists()) {
        final raw = await file.readAsBytes();
        final clear = await cipher.decrypt(
          SecretBox.fromConcatenation(raw, nonceLength: 12, macLength: 16),
          secretKey: key,
          aad: aad,
        );
        try {
          state = SignalState.restore(
            Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
          );
        } finally {
          clear.fillRange(0, clear.length, 0);
        }
      } else {
        state = await SignalState.create();
      }
      final result = await operation(state);
      final clear = utf8.encode(jsonEncode(state.serialize()));
      try {
        final encrypted = await cipher.encrypt(clear, secretKey: key, aad: aad);
        final temporary = File('${file.path}.pending');
        await temporary.writeAsBytes(encrypted.concatenation(), flush: true);
        await temporary.rename(file.path);
      } finally {
        clear.fillRange(0, clear.length, 0);
      }
      return result;
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }
}
