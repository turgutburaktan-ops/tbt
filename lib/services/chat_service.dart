import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';
import 'app_notification_service.dart';
import 'content_moderation_service.dart';
import 'social_service.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    } on TimeoutException {
      // Fall through to the normal logged-out error below.
    }

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

    await SocialService.instance.ensureUserProfile();
    final id = directThreadId(user.uid, otherUserId);
    final ref = _firestore.collection('chat_threads').doc(id);

    await ref.set({
      'type': 'direct',
      'memberIds': [user.uid, otherUserId],
      'sourceType': sourceType,
      'sourceId': sourceId,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return id;
  }

  Stream<List<ChatThread>> myThreads() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(const <ChatThread>[]);
      }

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

  Stream<List<ChatMessage>> messages(String threadId) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(const <ChatMessage>[]);
      }

      return _firestore
          .collection('chat_threads')
          .doc(threadId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ChatMessage.fromDocument)
                .where((message) => !message.deleted)
                .toList(growable: false),
          );
    });
  }

  Future<void> sendMessage({
    required String threadId,
    required String otherUserId,
    required String text,
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

    final expectedThreadId = directThreadId(user.uid, otherUserId);
    if (threadId != expectedThreadId) {
      throw Exception('Geçersiz sohbet kimliği.');
    }

    ContentModerationService.instance.enforce(clean);
    if (await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    _enforceClientRateLimit(clean);

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

    final messageRef = threadRef.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': user.uid,
      'text': clean,
      'createdAt': FieldValue.serverTimestamp(),
      'deleted': false,
    });
    batch.set(threadRef, {
      'lastMessage': clean,
      'lastSenderId': user.uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    final senderName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : 'Bir kullanıcı';
    final preview = clean.length > 90 ? '${clean.substring(0, 90)}…' : clean;
    try {
      await AppNotificationService.instance.notifyUser(
        userId: otherUserId,
        type: 'message',
        title: '$senderName sana mesaj gönderdi',
        body: preview,
        sourceId: threadId,
        actorId: user.uid,
      );
    } catch (_) {
      // Mesaj gönderildiyse bildirim yazma hatası sohbeti bozmaz.
    }
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
    if (otherUserId == user.uid) {
      throw Exception('Kendini raporlayamazsın.');
    }
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
