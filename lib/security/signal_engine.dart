import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

// All mutations are committed atomically by the encrypted, device-local vault.
// No private identity, prekey, session or history state is sent to Firebase.
class SignalState extends InMemorySignalProtocolStore {
  final IdentityKeyPair identity;
  final int registration;
  final Map<String, String> trusted = {};
  final Map<String, dynamic> history = {};
  final Map<String, dynamic> outbox = {};
  SignalState(this.identity, this.registration) : super(identity, registration);
  static String addressKey(SignalProtocolAddress a) =>
      jsonEncode([a.getName(), a.getDeviceId()]);
  static SignalProtocolAddress address(String value) {
    final a = jsonDecode(value) as List;
    return SignalProtocolAddress(a[0] as String, a[1] as int);
  }

  static Future<SignalState> create() async {
    final identity = generateIdentityKeyPair();
    final state = SignalState(identity, generateRegistrationId(false));
    for (final key in generatePreKeys(1, 100)) {
      await state.storePreKey(key.id, key);
    }
    final signed = generateSignedPreKey(identity, 1);
    await state.storeSignedPreKey(signed.id, signed);
    return state;
  }

  static SignalState restore(Map<String, dynamic> data) {
    if (data['version'] != 1)
      throw StateError('Desteklenmeyen şifreleme anahtarı.');
    final state = SignalState(
      IdentityKeyPair.fromSerialized(base64Decode(data['identity'] as String)),
      data['registration'] as int,
    );
    for (final entry in (data['sessions'] as Map).entries) {
      state.sessionStore.sessions[address(entry.key as String)] = base64Decode(
        entry.value as String,
      );
    }
    for (final entry in (data['preKeys'] as Map).entries) {
      state.preKeyStore.store[int.parse(entry.key as String)] = base64Decode(
        entry.value as String,
      );
    }
    for (final entry in (data['signedKeys'] as Map).entries) {
      state.signedPreKeyStore.store[int.parse(entry.key as String)] =
          base64Decode(entry.value as String);
    }
    state.trusted.addAll(Map<String, String>.from(data['trusted'] as Map));
    state.history.addAll(Map<String, dynamic>.from(data['history'] as Map));
    state.outbox.addAll(Map<String, dynamic>.from(data['outbox'] as Map));
    return state;
  }

  Map<String, dynamic> serialize() => {
    'version': 1,
    'identity': base64Encode(identity.serialize()),
    'registration': registration,
    'sessions': {
      for (final e in sessionStore.sessions.entries)
        addressKey(e.key): base64Encode(e.value),
    },
    'preKeys': {
      for (final e in preKeyStore.store.entries)
        e.key.toString(): base64Encode(e.value),
    },
    'signedKeys': {
      for (final e in signedPreKeyStore.store.entries)
        e.key.toString(): base64Encode(e.value),
    },
    'trusted': trusted,
    'history': history,
    'outbox': outbox,
  };
  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final key = trusted[addressKey(address)];
    return key == null ? null : IdentityKey.fromBytes(base64Decode(key), 0);
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? key,
    Direction direction,
  ) async {
    final prior = trusted[addressKey(address)];
    return key != null &&
        (prior == null || prior == base64Encode(key.serialize()));
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? key,
  ) async {
    if (key == null) throw StateError('Şifreleme kimliği eksik.');
    final encoded = base64Encode(key.serialize()), name = addressKey(address);
    if (trusted.containsKey(name) && trusted[name] != encoded)
      throw StateError(
        'Kişinin güvenlik anahtarı değişti. Gönderim durduruldu.',
      );
    final changed = trusted[name] != encoded;
    trusted[name] = encoded;
    return changed;
  }

  Future<Map<String, dynamic>> publicBundle() async {
    final signed = await loadSignedPreKey(1);
    return {
      'version': 1,
      'registrationId': registration,
      'deviceId': 1,
      'identityKey': base64Encode(identity.getPublicKey().serialize()),
      'signedPreKey': {
        'id': signed.id,
        'publicKey': base64Encode(signed.getKeyPair().publicKey.serialize()),
        'signature': base64Encode(signed.signature),
      },
      'preKeys': [
        for (final id in preKeyStore.store.keys)
          {
            'id': id,
            'publicKey': base64Encode(
              (await loadPreKey(id)).getKeyPair().publicKey.serialize(),
            ),
          },
      ],
    };
  }
}

class SignalEngine {
  final String uid;
  final SignalState state;
  SignalEngine(this.uid, this.state);
  static String cacheKey(String thread, String message) =>
      jsonEncode([thread, message]);
  static Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: canonical(value[k])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  static String digest(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
  Future<Map<String, dynamic>> encrypt({
    required String thread,
    required String message,
    required List<String> members,
    required Map<String, dynamic> content,
    required Future<Map<String, dynamic>> Function(String, bool) claimBundle,
  }) async {
    final recipients = members.toSet().toList()..sort();
    if (!recipients.contains(uid) ||
        recipients.length < 2 ||
        recipients.length > 50)
      throw StateError('Geçersiz sohbet üyeleri.');
    final context = {
      'version': 1,
      'thread': thread,
      'message': message,
      'sender': uid,
      'members': recipients,
      'content': content,
    };
    final key = cacheKey(thread, message), fingerprint = digest(context);
    final prior = state.outbox[key] as Map?;
    if (prior != null) {
      if (prior['fingerprint'] != fingerprint)
        throw StateError('Bu mesaj kimliği farklı içerikle kullanılamaz.');
      return Map<String, dynamic>.from(prior['packet'] as Map);
    }
    final envelopes = <String, dynamic>{};
    for (final peer in recipients.where((p) => p != uid)) {
      final address = SignalProtocolAddress(peer, 1);
      // Check the pinned identity on every send, even with an existing session.
      final hasSession = await state.containsSession(address);
      final bundle = await claimBundle(peer, !hasSession);
      final identity = IdentityKey.fromBytes(
        base64Decode(bundle['identityKey'] as String),
        0,
      );
      if (!await state.isTrustedIdentity(address, identity, Direction.sending))
        throw StateError('Kişinin güvenlik anahtarı değişti.');
      if (!hasSession) {
        final signed = bundle['signedPreKey'] as Map,
            pre = bundle['preKey'] as Map?;
        await SessionBuilder.fromSignalStore(
          state,
          address,
        ).processPreKeyBundle(
          PreKeyBundle(
            bundle['registrationId'] as int,
            1,
            pre?['id'] as int?,
            pre == null
                ? null
                : Curve.decodePoint(
                    base64Decode(pre['publicKey'] as String),
                    0,
                  ),
            signed['id'] as int,
            Curve.decodePoint(base64Decode(signed['publicKey'] as String), 0),
            base64Decode(signed['signature'] as String),
            identity,
          ),
        );
      }
      final encrypted = await SessionCipher.fromStore(
        state,
        address,
      ).encrypt(Uint8List.fromList(utf8.encode(jsonEncode(context))));
      envelopes[peer] = {
        'type': encrypted.getType(),
        'body': base64Encode(encrypted.serialize()),
      };
    }
    final packet = <String, dynamic>{
      'version': 1,
      'senderId': uid,
      'envelopes': envelopes,
    };
    state.outbox[key] = {'fingerprint': fingerprint, 'packet': packet};
    state.history[key] = {'digest': digest(packet), 'content': content};
    return packet;
  }

  Future<Map<String, dynamic>> decrypt({
    required String thread,
    required String message,
    required String sender,
    required Map<String, dynamic> packet,
  }) async {
    if (packet['version'] != 1 || packet['senderId'] != sender)
      throw StateError('Şifreli mesaj kimliği uyuşmuyor.');
    final key = cacheKey(thread, message),
        hash = digest(packet),
        cached = state.history[key] as Map?;
    if (cached != null) {
      if (cached['digest'] != hash)
        throw StateError('Şifreli mesaj değiştirildi.');
      return Map<String, dynamic>.from(cached['content'] as Map);
    }
    if (sender == uid)
      throw StateError('Bu mesajın yerel anahtarı bu cihazda bulunmuyor.');
    final item = (packet['envelopes'] as Map)[uid] as Map?;
    if (item == null)
      throw StateError('Bu mesaj için alıcı anahtarı bulunmuyor.');
    final bytes = base64Decode(item['body'] as String);
    if (bytes.length > 65536)
      throw StateError('Geçersiz şifreli mesaj boyutu.');
    final cipher = SessionCipher.fromStore(
      state,
      SignalProtocolAddress(sender, 1),
    );
    final Uint8List clear;
    if (item['type'] == CiphertextMessage.prekeyType) {
      final pre = PreKeySignalMessage(bytes);
      final session = await state.loadSession(SignalProtocolAddress(sender, 1));
      if (!session.hasSessionState(
        pre.getMessageVersion(),
        pre.getBaseKey().serialize(),
      )) {
        if (!await state.containsSignedPreKey(pre.getSignedPreKeyId()) ||
            (pre.getPreKeyId().isPresent &&
                !await state.containsPreKey(pre.getPreKeyId().value)))
          throw StateError('Mesajın ön anahtarı bulunamadı.');
      }
      clear = await cipher.decrypt(pre);
    } else if (item['type'] == CiphertextMessage.whisperType) {
      clear = await cipher.decryptFromSignal(
        SignalMessage.fromSerialized(bytes),
      );
    } else {
      throw StateError('Bilinmeyen şifreli mesaj biçimi.');
    }
    try {
      final decoded = jsonDecode(utf8.decode(clear)) as Map;
      if (decoded['version'] != 1 ||
          decoded['thread'] != thread ||
          decoded['message'] != message ||
          decoded['sender'] != sender ||
          !(decoded['members'] as List).contains(uid)) {
        throw StateError('Mesaj farklı bir sohbete ait.');
      }
      final content = Map<String, dynamic>.from(decoded['content'] as Map);
      state.history[key] = {'digest': hash, 'content': content};
      return content;
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }
}
