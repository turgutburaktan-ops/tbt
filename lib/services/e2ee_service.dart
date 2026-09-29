import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../security/attachment_cipher.dart';

import '../security/e2ee_vault.dart';
import '../security/signal_engine.dart';

class E2eeService {
  static final instance = E2eeService();
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Giriş yapmalısın.'));
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, String>> safetyCodes(List<String> peers) async {
    final uid = _uid;
    return E2eeVault.transaction(uid, (state) async {
      final result = <String, String>{};
      for (final peer in peers.where((p) => p != uid)) {
        final identity = await state.getIdentity(
          SignalProtocolAddress(peer, 1),
        );
        if (identity == null) {
          result[peer] = 'Bu kişiyle henüz anahtar alışverişi yapılmadı.';
          continue;
        }
        final identities = <String, String>{
          uid: base64Encode(state.identity.getPublicKey().serialize()),
          peer: base64Encode(identity.serialize()),
        };
        final ids = identities.keys.toList()..sort();
        final code = hashes.sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  for (final id in ids) [id, identities[id]],
                ]),
              ),
            )
            .toString();
        result[peer] = [
          for (var i = 0; i < code.length; i += 8) code.substring(i, i + 8),
        ].join(' ');
      }
      return result;
    });
  }

  Future<void> initialize() async {
    final uid = _uid;
    // Save locally before registration: a network failure must not replace keys.
    final bundle = await E2eeVault.transaction(
      uid,
      (state) => state.publicBundle(),
    );
    if (_uid != uid) throw StateError('Oturum değişti.');
    await _call('registerE2eeIdentity', bundle);
  }

  Future<Map<String, dynamic>> prepare(
    String threadId,
    String messageId,
    Map<String, dynamic> content, {
    String prefix = '',
    String scope = 'chat',
  }) async {
    final uid = _uid;
    await initialize();
    final collection = {
      'chat': 'chat_threads',
      'route': 'travel_plans',
      'event': 'social_events',
    }[scope];
    if (collection == null) throw StateError('Geçersiz sohbet.');
    final thread = await FirebaseFirestore.instance
        .doc('$collection/$threadId')
        .get(const GetOptions(source: Source.server));
    final members = scope == 'event'
        ? <String>{
            if (thread.data()?['hostId'] is String)
              thread.data()!['hostId'] as String,
            ...List<String>.from(thread.data()?['participantIds'] ?? []),
          }.toList()
        : List<String>.from(thread.data()?['memberIds'] ?? []);
    final packet = await E2eeVault.transaction(
      uid,
      (state) => SignalEngine(uid, state).encrypt(
        thread: '$prefix${scope == 'chat' ? '' : '$scope:'}$threadId',
        message: messageId,
        members: members,
        content: content,
        claimBundle: (peer, consumePreKey) => _call('claimE2eePreKey', {
          'threadId': threadId,
          'peerId': peer,
          'consumePreKey': consumePreKey,
          'scope': scope,
        }),
      ),
    );
    if (_uid != uid) throw StateError('Oturum değişti.');
    return packet;
  }

  Future<void> send(
    String threadId,
    String messageId,
    Map<String, dynamic> content, {
    String scope = 'chat',
  }) async {
    final packet = await prepare(threadId, messageId, content, scope: scope);
    // Retry uses the durable outbox packet, never a newly advanced ratchet.
    await _call('sendE2eeMessage', {
      'threadId': threadId,
      'messageId': messageId,
      'packet': packet,
      'scope': scope,
      'kind': content['type'] ?? 'text',
      if (content['type'] == 'poll')
        'pollOptionCount': (content['options'] as List).length,
    });
  }

  Future<void> edit(String threadId, String messageId, String text) async {
    if (text.trim().isEmpty || text.trim().length > 1500)
      throw StateError('Mesaj 1–1500 karakter olmalı.');
    final doc = await FirebaseFirestore.instance
        .doc('chat_threads/$threadId/messages/$messageId')
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    if (data == null ||
        data['senderId'] != _uid ||
        data['type'] != 'e2ee' ||
        data['encryptedKind'] != 'text')
      throw StateError('Bu mesaj şifreli olarak düzenlenemez.');
    final revision = (data['revision'] as int? ?? 0) + 1;
    final clear = await decode(threadId, messageId, data);
    if (clear['e2eeVerified'] != true)
      throw StateError('Mesajın anahtarı bulunmuyor.');
    final packet = await prepare(
      threadId,
      '$messageId:edit:$revision',
      {...clear, 'text': text.trim()}
        ..removeWhere((k, _) => ['createdAt', 'editedAt'].contains(k)),
    );
    await _call('sendE2eeMessage', {
      'threadId': threadId,
      'messageId': messageId,
      'packet': packet,
      'scope': 'chat',
      'kind': 'text',
      'revision': revision,
    });
  }

  Future<Map<String, dynamic>> preparePrivatePhoto(
    String threadId,
    String messageId,
    Uint8List bytes,
  ) async {
    final sealed = await AttachmentCipher.seal(
      bytes,
      'private_photo:$threadId:$messageId',
    );
    final packet = await prepare(threadId, messageId, {
      'key': sealed.key,
    }, prefix: 'private_photo:');
    return {'bytes': base64Encode(sealed.bytes), 'e2ee': packet};
  }

  Future<Uint8List> openPrivatePhoto(
    String threadId,
    String messageId,
    Map<String, dynamic> result,
  ) async {
    final uid = _uid, packet = Map<String, dynamic>.from(result['e2ee'] as Map);
    final secret = await E2eeVault.transaction(
      uid,
      (state) => SignalEngine(uid, state).decrypt(
        thread: 'private_photo:$threadId',
        message: messageId,
        sender: packet['senderId'] as String,
        packet: packet,
      ),
    );
    final bytes = await AttachmentCipher.open(
      base64Decode(result['bytes'] as String),
      secret['key'] as String,
      'private_photo:$threadId:$messageId',
      maxBytes: 512 * 1024,
    );
    if (_uid != uid) {
      bytes.fillRange(0, bytes.length, 0);
      throw StateError('Oturum değişti.');
    }
    return bytes;
  }

  Future<Map<String, dynamic>> decode(
    String threadId,
    String messageId,
    Map<String, dynamic> data, {
    String scope = 'chat',
  }) async {
    if (data['type'] != 'e2ee') return data;
    if (data['deleted'] == true) return {...data, 'text': 'Mesaj geri alındı'};
    final uid = _uid;
    try {
      final content = await E2eeVault.transaction(
        uid,
        (state) => SignalEngine(uid, state).decrypt(
          thread: '${scope == 'chat' ? '' : '$scope:'}$threadId',
          message: (data['revision'] as int? ?? 0) > 0
              ? '$messageId:edit:${data['revision']}'
              : messageId,
          sender: data['senderId'] as String,
          packet: Map<String, dynamic>.from(data['e2ee'] as Map),
        ),
      );
      if (_uid != uid) throw StateError('Oturum değişti.');
      // Routing, attribution and lifecycle fields always come from the document.
      return {
        ...content,
        'senderId': data['senderId'],
        'senderName': content['senderName'] ?? data['senderName'],
        'createdAt': data['createdAt'],
        'deleted': data['deleted'],
        'editedAt': data['editedAt'],
        'reactions': data['reactions'],
        'votes': data['votes'],
        'closed': data['closed'],
        'e2eeVerified': true,
      };
    } catch (_) {
      return {
        ...data,
        'text': 'Şifreli mesaj açılamadı. Anahtar bu cihazda bulunmuyor veya doğrulama başarısız.',
        'type': 'text',
        'mediaUrl': null,
      };
    }
  }

  Future<String> upload(
    String threadId,
    String messageId,
    Uint8List bytes, {
    required String contentType,
    String scope = 'chat',
  }) async {
    await initialize();
    final uid = _uid;
    final path = 'e2ee_$scope/$threadId/$uid/$messageId/payload.bin';
    final sealed = await AttachmentCipher.seal(bytes, path);
    if (_uid != uid) throw StateError('Oturum değişti.');
    await FirebaseStorage.instance
        .ref(path)
        .putData(
          sealed.bytes,
          SettableMetadata(
            contentType: 'application/octet-stream',
            cacheControl: 'private, no-store',
          ),
        );
    // Descriptor is included only inside a Signal-encrypted message.
    return 'tbt-e2ee:${base64UrlEncode(utf8.encode(jsonEncode({'version': 1, 'path': path, 'key': sealed.key, 'contentType': contentType})))}';
  }

  static Future<Uint8List> readAttachment(
    String descriptor, {
    required int maxBytes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Giriş yapmalısın.');
    final data = jsonDecode(
      utf8.decode(base64Url.decode(descriptor.substring('tbt-e2ee:'.length))),
    ) as Map;
    final path = data['path'] as String;
    if (data['version'] != 1 ||
        !RegExp(r'^e2ee_(chat|route|event)/[^/]+/[^/]+/[^/]+/payload\.bin$')
            .hasMatch(path))
      throw StateError('Geçersiz şifreli medya.');
    final raw = await FirebaseStorage.instance.ref(path).getData(maxBytes + 28);
    if (raw == null || FirebaseAuth.instance.currentUser?.uid != uid)
      throw StateError('Medya erişimi sona erdi.');
    final clear = await AttachmentCipher.open(
      raw,
      data['key'] as String,
      path,
      maxBytes: maxBytes,
    );
    if (FirebaseAuth.instance.currentUser?.uid != uid ||
        clear.length > maxBytes) {
      clear.fillRange(0, clear.length, 0);
      throw StateError('Medya erişimi sona erdi.');
    }
    final result = Uint8List.fromList(clear);
    clear.fillRange(0, clear.length, 0);
    return result;
  }
}
