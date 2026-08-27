import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/chat_message.dart';
import 'app_notification_service.dart';
import 'content_moderation_service.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final List<DateTime> _recentSends = <DateTime>[];
  String? _lastMessageFingerprint;
  DateTime? _lastMessageAt;

  Future<User> _requiredUser() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    try {
      final restored = await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 3));
      if (restored != null) return restored;
    } on TimeoutException {}
    throw Exception('Mesajlaşmak için giriş yapmalısın.');
  }

  String directThreadId(String a, String b) {
    final ids = [a, b]..sort();
    return 'dm_${ids[0]}_${ids[1]}';
  }

  void _enforceClientRateLimit(String text) {
    final now = DateTime.now();
    _recentSends.removeWhere(
      (time) => now.difference(time) > const Duration(seconds: 20),
    );
    if (_recentSends.length >= 8) {
      throw Exception('Çok hızlı mesaj gönderiyorsun. Birkaç saniye bekle.');
    }
    final fingerprint = text.trim().toLowerCase();
    final repeatedTooFast =
        _lastMessageFingerprint == fingerprint &&
        _lastMessageAt != null &&
        now.difference(_lastMessageAt!) < const Duration(seconds: 4);
    if (repeatedTooFast) {
      throw Exception('Aynı mesajı art arda çok hızlı gönderemezsin.');
    }
    _recentSends.add(now);
    _lastMessageFingerprint = fingerprint;
    _lastMessageAt = now;
  }

  Future<bool> isBlockedBetween(String otherUserId) async {
    final me = (await _requiredUser()).uid;
    final refs = await Future.wait([
      _firestore
          .collection('users')
          .doc(me)
          .collection('blocked')
          .doc(otherUserId)
          .get(),
      _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('blocked')
          .doc(me)
          .get(),
    ]);
    return refs.any((doc) => doc.exists);
  }

  Future<String> ensureDirectThread(
    String otherUserId, {
    String? sourceType,
    String? sourceId,
  }) async {
    final user = await _requiredUser();
    if (otherUserId == user.uid) {
      throw Exception('Kendine mesaj gönderemezsin.');
    }
    if (await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }

    final id = directThreadId(user.uid, otherUserId);
    final ref = _firestore.collection('chat_threads').doc(id);
    final existing = await ref.get();
    if (existing.exists) {
      final data = existing.data() ?? const <String, dynamic>{};
      final members = (data['memberIds'] as List? ?? const <dynamic>[])
          .map((value) => value.toString())
          .toList(growable: false);
      final valid =
          (data['type'] ?? '').toString() == 'direct' &&
          members.length == 2 &&
          members.contains(user.uid) &&
          members.contains(otherUserId);
      if (!valid) throw Exception('Bu sohbete erişimin yok.');
      return id;
    }

    // Keep initial thread creation deliberately minimal. Extra UX metadata is
    // best-effort so a rules/version mismatch can never block core messaging.
    await ref.set({
      'type': 'direct',
      'memberIds': [user.uid, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await ref.set({
        'sourceType': sourceType,
        'sourceId': sourceId,
        'lastReadAt': {user.uid: FieldValue.serverTimestamp()},
        'typingAt': <String, dynamic>{},
        'messageReactions': <String, dynamic>{},
        'deletedMessageIds': <String>[],
      }, SetOptions(merge: true));
    } catch (_) {}
    return id;
  }

  Stream<List<ChatThread>> myThreads() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <ChatThread>[]);
      return _firestore
          .collection('chat_threads')
          .where('memberIds', arrayContains: user.uid)
          .snapshots()
          .map((snapshot) {
            final items = snapshot.docs.map(ChatThread.fromDocument).toList();
            items.sort((a, b) {
              final ad =
                  a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bd =
                  b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });
            return items;
          });
    });
  }

  Stream<ChatThread?> watchThread(String threadId) {
    return _firestore
        .collection('chat_threads')
        .doc(threadId)
        .snapshots()
        .map((doc) => doc.exists ? ChatThread.fromDocument(doc) : null);
  }

  Stream<List<ChatMessage>> messages(String threadId) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <ChatMessage>[]);
      return _firestore
          .collection('chat_threads')
          .doc(threadId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(150)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ChatMessage.fromDocument)
                .toList(growable: false),
          );
    });
  }

  Future<void> markThreadRead(String threadId) async {
    final user = await _requiredUser();
    try {
      await _firestore.collection('chat_threads').doc(threadId).update({
        'lastReadAt.${user.uid}': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> setTyping(String threadId, bool typing) async {
    final user = await _requiredUser();
    try {
      await _firestore.collection('chat_threads').doc(threadId).update({
        'typingAt.${user.uid}': typing
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<void> setPresence(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'isOnline': online,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String emoji,
  }) async {
    final user = await _requiredUser();
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final thread = await threadRef.get();
    final data = thread.data() ?? const <String, dynamic>{};
    final members = (data['memberIds'] as List? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(growable: false);
    if (!members.contains(user.uid)) {
      throw Exception('Bu sohbete erişimin yok.');
    }
    final deletedIds = (data['deletedMessageIds'] as List? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toSet();
    if (deletedIds.contains(messageId)) return;
    final raw = data['messageReactions'];
    String? current;
    if (raw is Map && raw[messageId] is Map) {
      current = (raw[messageId] as Map)[user.uid]?.toString();
    }
    await threadRef.update({
      'messageReactions.$messageId.${user.uid}': current == emoji
          ? FieldValue.delete()
          : emoji,
    });
  }

  Future<void> deleteForEveryone({
    required String threadId,
    required String messageId,
  }) async {
    final user = await _requiredUser();
    final message = await _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .doc(messageId)
        .get();
    if (!message.exists) return;
    if ((message.data()?['senderId'] ?? '').toString() != user.uid) {
      throw Exception('Sadece kendi mesajını geri alabilirsin.');
    }
    await _firestore.collection('chat_threads').doc(threadId).update({
      'deletedMessageIds': FieldValue.arrayUnion([messageId]),
      'messageReactions.$messageId': FieldValue.delete(),
    });
  }

  Future<void> sendMessage({
    required String threadId,
    required String otherUserId,
    required String text,
    ChatMessage? replyTo,
  }) async {
    final user = await _requiredUser();
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (clean.length > 1500) {
      throw Exception('Mesaj en fazla 1500 karakter olabilir.');
    }
    if (otherUserId == user.uid) {
      throw Exception('Kendine mesaj gönderemezsin.');
    }
    if (threadId != directThreadId(user.uid, otherUserId)) {
      throw Exception('Geçersiz sohbet kimliği.');
    }
    ContentModerationService.instance.enforce(clean);
    if (await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    _enforceClientRateLimit(clean);
    await _sendPreparedMessage(
      threadId: threadId,
      otherUserId: otherUserId,
      text: clean,
      type: 'text',
      replyTo: replyTo,
    );
  }

  Future<void> sendImageMessage({
    required String threadId,
    required String otherUserId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    ChatMessage? replyTo,
  }) async {
    final user = await _requiredUser();
    if (bytes.isEmpty) throw Exception('Fotoğraf okunamadı.');
    if (bytes.lengthInBytes > 15 * 1024 * 1024) {
      throw Exception('Fotoğraf en fazla 15 MB olabilir.');
    }
    if (await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    final messageRef = _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .doc();
    final ext = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
        ? 'webp'
        : 'jpg';
    final storageRef = _storage.ref(
      'users/${user.uid}/chat/$threadId/${messageRef.id}.$ext',
    );
    await storageRef.putData(bytes, SettableMetadata(contentType: contentType));
    final mediaUrl = await storageRef.getDownloadURL();
    await _sendPreparedMessage(
      threadId: threadId,
      otherUserId: otherUserId,
      text: '📷 Fotoğraf',
      type: 'image',
      mediaUrl: mediaUrl,
      replyTo: replyTo,
      forcedMessageRef: messageRef,
    );
  }

  Future<void> sendAudioMessage({
    required String threadId,
    required String otherUserId,
    required Uint8List bytes,
    int? durationMs,
    ChatMessage? replyTo,
  }) async {
    final user = await _requiredUser();
    if (bytes.isEmpty) throw Exception('Ses kaydı okunamadı.');
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      throw Exception('Sesli mesaj en fazla 20 MB olabilir.');
    }
    if (await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    final messageRef = _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .doc();
    final storageRef = _storage.ref(
      'users/${user.uid}/chat/$threadId/${messageRef.id}.m4a',
    );
    await storageRef.putData(bytes, SettableMetadata(contentType: 'audio/mp4'));
    final mediaUrl = await storageRef.getDownloadURL();
    await _sendPreparedMessage(
      threadId: threadId,
      otherUserId: otherUserId,
      text: '🎙️ Sesli mesaj',
      type: 'audio',
      mediaUrl: mediaUrl,
      durationMs: durationMs,
      replyTo: replyTo,
      forcedMessageRef: messageRef,
    );
  }

  Future<void> sendSharedContent({
    required String threadId,
    required String otherUserId,
    required String sharedType,
    required String sharedId,
    required String title,
    String? imageUrl,
  }) async {
    final label = sharedType == 'event'
        ? '📅 Etkinlik'
        : sharedType == 'reel'
        ? '▶️ Reels'
        : '📷 Gönderi';
    await _sendPreparedMessage(
      threadId: threadId,
      otherUserId: otherUserId,
      text: '$label • $title',
      type: 'share',
      sharedType: sharedType,
      sharedId: sharedId,
      sharedTitle: title,
      sharedImageUrl: imageUrl,
    );
  }

  Future<void> _sendPreparedMessage({
    required String threadId,
    required String otherUserId,
    required String text,
    required String type,
    String? mediaUrl,
    int? durationMs,
    ChatMessage? replyTo,
    DocumentReference<Map<String, dynamic>>? forcedMessageRef,
    String? sharedType,
    String? sharedId,
    String? sharedTitle,
    String? sharedImageUrl,
  }) async {
    final user = await _requiredUser();
    final threadRef = _firestore.collection('chat_threads').doc(threadId);
    final thread = await threadRef.get();
    final members =
        (thread.data()?['memberIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    if (members.length != 2 ||
        !members.contains(user.uid) ||
        !members.contains(otherUserId)) {
      throw Exception('Bu sohbete erişimin yok.');
    }

    final messageRef =
        forcedMessageRef ?? threadRef.collection('messages').doc();
    final messageData = <String, dynamic>{
      'senderId': user.uid,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'durationMs': durationMs,
      'replyToId': replyTo?.id,
      'replyText': replyTo == null
          ? null
          : (replyTo.isImage
                ? '📷 Fotoğraf'
                : replyTo.isAudio
                ? '🎙️ Sesli mesaj'
                : replyTo.text),
      'replySenderId': replyTo?.senderId,
      'sharedType': sharedType,
      'sharedId': sharedId,
      'sharedTitle': sharedTitle,
      'sharedImageUrl': sharedImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    };

    // Core reliability rule: message creation must not be coupled to optional
    // thread metadata. If the metadata rule is stale, the DM still sends.
    await messageRef.set(messageData);

    final lastMessage = type == 'image'
        ? '📷 Fotoğraf'
        : type == 'audio'
        ? '🎙️ Sesli mesaj'
        : text;
    try {
      await threadRef.set({
        'lastMessage': lastMessage,
        'lastSenderId': user.uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    try {
      await markThreadRead(threadId);
      await setTyping(threadId, false);
    } catch (_) {}

    final senderName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : 'Bir kullanıcı';
    final preview = type == 'image'
        ? 'Sana bir fotoğraf gönderdi'
        : type == 'audio'
        ? 'Sana bir sesli mesaj gönderdi'
        : type == 'share'
        ? 'Seninle bir içerik paylaştı'
        : (text.length > 90 ? '${text.substring(0, 90)}…' : text);
    try {
      await AppNotificationService.instance.notifyUser(
        userId: otherUserId,
        type: 'message',
        title: '$senderName sana mesaj gönderdi',
        body: preview,
        sourceId: threadId,
        actorId: user.uid,
      );
    } catch (_) {}
  }

  Future<void> blockUser(String otherUserId) async {
    final user = await _requiredUser();
    if (otherUserId == user.uid) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('blocked')
        .doc(otherUserId)
        .set({
          'userId': otherUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> unblockUser(String otherUserId) async {
    final user = await _requiredUser();
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('blocked')
        .doc(otherUserId)
        .delete();
  }

  Future<void> reportUser({
    required String otherUserId,
    required String reason,
    String? threadId,
  }) async {
    final user = await _requiredUser();
    if (otherUserId == user.uid) throw Exception('Kendini raporlayamazsın.');
    await _firestore.collection('user_reports').add({
      'reporterId': user.uid,
      'reportedUserId': otherUserId,
      'threadId': threadId,
      'reason': reason.trim().isEmpty ? 'unspecified' : reason.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
