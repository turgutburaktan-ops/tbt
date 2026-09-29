import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/chat_message.dart';
import 'auth_switch_stream.dart';
import 'chat_history_filter.dart';
import 'content_moderation_service.dart';
import 'e2ee_service.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, DateTime> _delivered = {};
  final List<DateTime> _recentSends = <DateTime>[];
  final Map<String, bool> _typingState = <String, bool>{};
  final Map<String, Future<void>> _reactionInFlight = <String, Future<void>>{};
  String? _lastMessageFingerprint;
  DateTime? _lastMessageAt;
  bool? _lastPresenceValue;
  DateTime? _lastPresenceAt;

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
          .get()
          .timeout(const Duration(seconds: 5)),
      _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('blocked')
          .doc(me)
          .get()
          .timeout(const Duration(seconds: 5)),
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
    if (otherUserId.isNotEmpty && await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }

    final id = directThreadId(user.uid, otherUserId);
    final ref = _firestore.collection('chat_threads').doc(id);
    final existing = await ref.get().timeout(const Duration(seconds: 6));
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
      if (data['requestStatus'] != 'pending' && data['requestStatus'] != 'rejected') return id;
    }

    final result = await action('direct', {'otherUserId': otherUserId});
    return result['threadId'] as String;
  }

  Future<void> _initializeThreadMetadata({
    required DocumentReference<Map<String, dynamic>> ref,
    required String userId,
    String? sourceType,
    String? sourceId,
  }) async {
    try {
      await ref.set({
        'sourceType': sourceType,
        'sourceId': sourceId,
        'lastReadAt': {userId: FieldValue.serverTimestamp()},
        'typingAt': <String, dynamic>{},
        'messageReactions': <String, dynamic>{},
        'deletedMessageIds': <String>[],
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Stream<List<ChatThread>> myThreads() {
    return switchAuthStream<List<ChatThread>>(
      auth: _auth,
      signedOutValue: const <ChatThread>[],
      signedIn: (user) => combineChatSnapshots(
        _firestore
          .collection('chat_threads')
          .where('memberIds', arrayContains: user.uid)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map(ChatThread.fromDocument).toList();
          }),
        _firestore.collection('users').doc(user.uid)
            .collection('chat_preferences').snapshots(),
        (threads, preferences) {
            final cutoffs = {for (final doc in preferences.docs)
              doc.id: (doc.data()['deletedAt'] as Timestamp?)?.toDate()};
            final items = threads.where((thread) => visibleAfterChatDeletion(
              thread.lastMessageAt, cutoffs[thread.id])).toList();
            for (final t in items) {
              if (t.lastSenderId != user.uid && t.lastMessageAt != null && _delivered[t.id] != t.lastMessageAt) {
                _delivered[t.id] = t.lastMessageAt!;
                unawaited(_firestore.collection('chat_threads').doc(t.id).update({'lastDeliveredAt.${user.uid}': FieldValue.serverTimestamp()}).catchError((Object e) { _delivered.remove(t.id); }));
              }
            }
            items.sort((a, b) {
              final ad =
                  a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bd =
                  b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });
            return items;
        },
      ),
    );
  }

  Stream<int> unreadThreadCount() {
    return switchAuthStream<int>(
      auth: _auth,
      signedOutValue: 0,
      signedIn: (user) => myThreads().map((threads) {
        return threads.where((thread) {
          if (thread.lastSenderId == user.uid || thread.lastMessageAt == null) {
            return false;
          }
          final lastRead = thread.lastReadAt[user.uid];
          return lastRead == null || thread.lastMessageAt!.isAfter(lastRead);
        }).length;
      }),
    ).distinct();
  }

  Stream<ChatThread?> watchThread(String threadId) {
    return switchAuthStream<ChatThread?>(
      auth: _auth,
      signedOutValue: null,
      signedIn: (_) => _firestore
          .collection('chat_threads')
          .doc(threadId)
          .snapshots()
          .map((doc) => doc.exists ? ChatThread.fromDocument(doc) : null),
    );
  }

  Stream<List<ChatMessage>> messages(String threadId) {
    return switchAuthStream<List<ChatMessage>>(
      auth: _auth,
      signedOutValue: const <ChatMessage>[],
      signedIn: (user) => combineChatSnapshots(
        _firestore.collection('chat_threads').doc(threadId)
            .collection('messages').orderBy('createdAt', descending: true)
            .limit(150).snapshots(includeMetadataChanges: true),
        _firestore.collection('users').doc(user.uid)
            .collection('chat_preferences').doc(threadId).snapshots(),
        (snapshot, preferences) {
          final cutoff = (preferences.data()?['deletedAt'] as Timestamp?)?.toDate();
          return snapshot.docs.where((doc) => visibleAfterChatDeletion(
            (doc.data()['createdAt'] as Timestamp?)?.toDate(), cutoff,
            pending: doc.metadata.hasPendingWrites,
          )).toList(growable: false);
        },
      ).asyncMap((docs) async {
        final result = <ChatMessage>[];
        // Serialized vault operations also preserve ratchet state for fast snapshots.
        for (final doc in docs.reversed) {
          final decoded = await E2eeService.instance.decode(threadId,doc.id,doc.data());
          if (_auth.currentUser?.uid != user.uid) return <ChatMessage>[];
          result.add(ChatMessage.fromDocument(doc,decrypted:decoded));
        }
        return result.reversed.toList();
      }),
    );
  }

  Stream<ChatMessage?> visibleMessage(String threadId, String messageId) {
    return switchAuthStream<ChatMessage?>(
      auth: _auth,
      signedOutValue: null,
      signedIn: (user) => combineChatSnapshots(
        _firestore.doc('chat_threads/$threadId/messages/$messageId').snapshots(),
        _firestore.doc('users/${user.uid}/chat_preferences/$threadId').snapshots(),
        (message, preferences) {
          if (!message.exists) return null;
          final cutoff = (preferences.data()?['deletedAt'] as Timestamp?)?.toDate();
          if (!visibleAfterChatDeletion(
              (message.data()?['createdAt'] as Timestamp?)?.toDate(), cutoff)) return null;
          return message;
        },
      ).asyncMap((doc) async {
        if (doc == null) return null;
        final decoded = await E2eeService.instance.decode(threadId,doc.id,doc.data()!);
        if (_auth.currentUser?.uid != user.uid) return null;
        return ChatMessage.fromDocument(doc,decrypted:decoded);
      }),
    );
  }

  Future<void> deleteConversation(String threadId) async {
    await action('deleteConversation', {'threadId': threadId});
  }

  Future<Map<String, dynamic>> action(String action, Map<String, dynamic> data) async {
    if(action=='edit') {
      await E2eeService.instance.edit(data['threadId'] as String,data['messageId'] as String,data['text'] as String);
      return {'ok':true};
    }
    if(action=='poll') {
      final options=List<String>.from(data['options'] as List);
      final question=(data['question'] as String).trim();
      if(question.isEmpty||question.length>200||options.length<2||options.length>6||options.toSet().length!=options.length||options.any((s)=>s.isEmpty||s.length>120))throw StateError('2–6 farklı seçenek ve bir soru yaz.');
      final threadId=data['threadId'] as String;
      final messageId=_firestore.collection('chat_threads').doc(threadId).collection('messages').doc().id;
      await E2eeService.instance.send(threadId,messageId,{'type':'poll','text':question,'options':options,'senderName':_auth.currentUser?.displayName??'Üye'});
      return {'ok':true};
    }
    final result = await FirebaseFunctions.instance.httpsCallable('chatAction').call({'action': action, ...data});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> markThreadRead(String threadId) async {
    final user = await _requiredUser();
    try {
      final profile = await _firestore.collection('users').doc(user.uid).get();
      if (profile.data()?['showReadReceipts'] == false) return;
      final prefs = await _firestore.doc('users/${user.uid}/chat_preferences/$threadId').get();
      if (prefs.data()?['readReceipts'] == false) return;
      await _firestore.collection('chat_threads').doc(threadId).update({
        'lastReadAt.${user.uid}': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> setTyping(String threadId, bool typing) async {
    final user = await _requiredUser();
    final key = '${user.uid}:$threadId';
    if (_typingState[key] == typing) return;
    _typingState[key] = typing;
    try {
      await _firestore.collection('chat_threads').doc(threadId).update({
        'typingAt.${user.uid}': typing
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      if (_typingState[key] == typing) _typingState.remove(key);
    }
  }

  Future<void> refreshPresence() async {
    if (_auth.currentUser != null) {
      unawaited(E2eeService.instance.initialize().catchError((Object _) {}));
    }
    _lastPresenceValue = null;
    _lastPresenceAt = null;
    await setPresence(true);
  }

  Future<void> setPresence(bool online) async {
    final user = _auth.currentUser;
    if (user == null) {
      _lastPresenceValue = null;
      _lastPresenceAt = null;
      return;
    }
    final now = DateTime.now();
    if (_lastPresenceValue == online &&
        _lastPresenceAt != null &&
        now.difference(_lastPresenceAt!) < const Duration(minutes: 2)) {
      return;
    }
    try {
      final profile = await _firestore.collection('users').doc(user.uid).get();
      if (profile.data()?['showOnlineStatus'] == false) {
        _lastPresenceValue = null;
        _lastPresenceAt = null;
        return;
      }
      await _firestore.collection('users').doc(user.uid).set({
        'isOnline': online,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      _lastPresenceValue = online;
      _lastPresenceAt = now;
    } catch (_) {}
  }

  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String emoji,
  }) {
    final key = '$threadId:$messageId';
    final running = _reactionInFlight[key];
    if (running != null) return running;
    final request = _toggleReactionInternal(
      threadId: threadId,
      messageId: messageId,
      emoji: emoji,
    );
    _reactionInFlight[key] = request;
    return request.whenComplete(() {
      if (identical(_reactionInFlight[key], request)) {
        _reactionInFlight.remove(key);
      }
    });
  }

  Future<void> _toggleReactionInternal({
    required String threadId,
    required String messageId,
    required String emoji,
  }) async {
    await action('reaction', {'threadId': threadId, 'messageId': messageId, 'emoji': emoji});
  }

  Future<void> deleteForEveryone({required String threadId, required String messageId}) async {
    await action('delete', {'threadId': threadId, 'messageId': messageId});
  }

  Future<void> sendMessage({
    required String threadId,
    required String otherUserId,
    required String text,
    ChatMessage? replyTo,
    String? clientMessageId,
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
    if (otherUserId.isNotEmpty && threadId != directThreadId(user.uid, otherUserId)) {
      throw Exception('Geçersiz sohbet kimliği.');
    }
    ContentModerationService.instance.enforce(clean);
    if (otherUserId.isNotEmpty && await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    _enforceClientRateLimit(clean);
    await _sendPreparedMessage(
      threadId: threadId,
      otherUserId: otherUserId,
      text: clean,
      type: 'text',
      replyTo: replyTo,
      forcedMessageRef: clientMessageId == null ? null : _firestore.collection('chat_threads').doc(threadId).collection('messages').doc(clientMessageId),
    );
  }

  Future<void> sendImageMessage({
    required String threadId,
    required String otherUserId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    ChatMessage? replyTo,
  }) async {
    await _requiredUser();
    if (bytes.isEmpty) throw Exception('Fotoğraf okunamadı.');
    if (bytes.lengthInBytes > 15 * 1024 * 1024) {
      throw Exception('Fotoğraf en fazla 15 MB olabilir.');
    }
    if (otherUserId.isNotEmpty && await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    final messageRef = _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .doc();
    final mediaUrl = await E2eeService.instance.upload(threadId,messageRef.id,bytes,contentType:contentType);
    await _sendPreparedMessage(threadId:threadId,otherUserId:otherUserId,text:'📷 Fotoğraf',type:'image',mediaUrl:mediaUrl,replyTo:replyTo,forcedMessageRef:messageRef);
  }

  Future<void> sendAudioMessage({
    required String threadId,
    required String otherUserId,
    required Uint8List bytes,
    int? durationMs,
    ChatMessage? replyTo,
  }) async {
    await _requiredUser();
    if (bytes.isEmpty) throw Exception('Ses kaydı okunamadı.');
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      throw Exception('Sesli mesaj en fazla 20 MB olabilir.');
    }
    if (otherUserId.isNotEmpty && await isBlockedBetween(otherUserId)) {
      throw Exception('Bu kullanıcıyla mesajlaşma kullanılamıyor.');
    }
    final messageRef = _firestore
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .doc();
    final mediaUrl = await E2eeService.instance.upload(threadId,messageRef.id,bytes,contentType:'audio/mp4');
    await _sendPreparedMessage(threadId:threadId,otherUserId:otherUserId,text:'🎙️ Sesli mesaj',type:'audio',mediaUrl:mediaUrl,durationMs:durationMs,replyTo:replyTo,forcedMessageRef:messageRef);
  }

  Future<void> sendSharedContent({
    required String threadId,
    required String otherUserId,
    required String sharedType,
    required String sharedId,
    required String title,
    String? imageUrl,
  }) async {
    final label = sharedType == 'route' ? '🗺️ Rota' : sharedType == 'event'
        ? '📅 Etkinlik'
        : sharedType == 'venue'
        ? '📍 Mekan'
        : sharedType == 'spot'
        ? '📍 Çekim noktası'
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
    final thread = await threadRef.get().timeout(const Duration(seconds: 6));
    final members =
        (thread.data()?['memberIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final isGroup = thread.data()?['type'] == 'group';
    if (!members.contains(user.uid) || (!isGroup && (members.length != 2 || !members.contains(otherUserId)))) {
      throw Exception('Bu sohbete erişimin yok.');
    }

    final messageRef =
        forcedMessageRef ?? threadRef.collection('messages').doc();
    final messageData = <String, dynamic>{
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Üye',
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

    // Firebase receives neither the payload nor a plaintext preview.
    messageData.remove('createdAt');
    await E2eeService.instance.send(threadId,messageRef.id,messageData);
    unawaited(markThreadRead(threadId));
    unawaited(setTyping(threadId,false));
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
        })
        .timeout(const Duration(seconds: 8));
  }

  Future<void> unblockUser(String otherUserId) async {
    final user = await _requiredUser();
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('blocked')
        .doc(otherUserId)
        .delete()
        .timeout(const Duration(seconds: 8));
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
    }).timeout(const Duration(seconds: 8));
  }
}


