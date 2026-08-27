import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_notification_service.dart';
import 'chat_service.dart';
import 'content_moderation_service.dart';

class ContentEngagementService {
  ContentEngagementService._();
  static final ContentEngagementService instance = ContentEngagementService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _ref(String collection, String id) =>
      _firestore.collection(collection).doc(id);

  Stream<bool> isLiked(String collection, String id) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _ref(
      collection,
      id,
    ).collection('likes').doc(uid).snapshots().map((s) => s.exists);
  }

  Stream<int> likesCount(String collection, String id) => _ref(
    collection,
    id,
  ).collection('likes').snapshots().map((s) => s.docs.length);

  Future<void> toggleLike({
    required String collection,
    required String id,
    required String ownerId,
    required String title,
    required String sourceType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Beğenmek için giriş yapmalısın.');
    final likeRef = _ref(collection, id).collection('likes').doc(user.uid);
    final existing = await likeRef.get();
    if (existing.exists) {
      await likeRef.delete();
      return;
    }
    await likeRef.set({
      'userId': user.uid,
      'userName': (user.displayName ?? '').trim().isEmpty
          ? 'Bir kullanıcı'
          : user.displayName!.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (ownerId.isNotEmpty && ownerId != user.uid) {
      try {
        await AppNotificationService.instance.notifyUser(
          userId: ownerId,
          type: '${sourceType}_like',
          title:
              '${(user.displayName ?? '').trim().isEmpty ? 'Bir kullanıcı' : user.displayName!.trim()} beğendi',
          body: title,
          sourceId: id,
          actorId: user.uid,
        );
      } catch (_) {}
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> comments(
    String collection,
    String id,
  ) => _ref(
    collection,
    id,
  ).collection('comments').orderBy('createdAt', descending: false).snapshots();

  Future<void> addComment({
    required String collection,
    required String id,
    required String ownerId,
    required String title,
    required String text,
    required String sourceType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Yorum yapmak için giriş yapmalısın.');
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (clean.length > 500) {
      throw Exception('Yorum en fazla 500 karakter olabilir.');
    }
    ContentModerationService.instance.enforce(clean);
    await _ref(collection, id).collection('comments').add({
      'userId': user.uid,
      'userName': (user.displayName ?? '').trim().isEmpty
          ? 'Fotoğrafçı'
          : user.displayName!.trim(),
      'text': clean,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (ownerId.isNotEmpty && ownerId != user.uid) {
      try {
        await AppNotificationService.instance.notifyUser(
          userId: ownerId,
          type: '${sourceType}_comment',
          title:
              '${(user.displayName ?? '').trim().isEmpty ? 'Bir kullanıcı' : user.displayName!.trim()} yorum yaptı',
          body: clean.length > 90 ? '${clean.substring(0, 90)}…' : clean,
          sourceId: id,
          actorId: user.uid,
        );
      } catch (_) {}
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> tags(
    String collection,
    String id,
  ) => _ref(collection, id).collection('tags').snapshots();

  Future<void> tagUser({
    required String collection,
    required String id,
    required String userId,
    required String userName,
    required String title,
    required String sourceType,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw Exception('Etiketlemek için giriş yapmalısın.');
    if (userId.isEmpty) return;
    await _ref(collection, id).collection('tags').doc(userId).set({
      'userId': userId,
      'userName': userName,
      'taggedBy': me.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (userId != me.uid) {
      try {
        await AppNotificationService.instance.notifyUser(
          userId: userId,
          type: '${sourceType}_tag',
          title:
              '${(me.displayName ?? '').trim().isEmpty ? 'Bir kullanıcı' : me.displayName!.trim()} seni etiketledi',
          body: title,
          sourceId: id,
          actorId: me.uid,
        );
      } catch (_) {}
    }
  }

  Future<void> shareToUser({
    required String targetUserId,
    required String sourceType,
    required String sourceId,
    required String title,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw Exception('Göndermek için giriş yapmalısın.');
    if (targetUserId.trim().isEmpty || sourceId.trim().isEmpty) {
      throw Exception('Paylaşılacak içerik bulunamadı.');
    }

    final threadId = await ChatService.instance.ensureDirectThread(
      targetUserId,
      sourceType: sourceType,
      sourceId: sourceId,
    );

    String sharedType;
    String collection;
    if (sourceType == 'social_event' || sourceType == 'event') {
      sharedType = 'event';
      collection = 'social_events';
    } else if (sourceType == 'reel') {
      sharedType = 'reel';
      collection = 'posts';
    } else {
      sharedType = 'post';
      collection = 'posts';
    }

    String? imageUrl;
    try {
      final snap = await _firestore.collection(collection).doc(sourceId).get();
      final data = snap.data();
      if (data != null) {
        final candidates = sharedType == 'event'
            ? [data['coverImageUrl'], data['imageUrl'], data['photoUrl']]
            : [data['thumbnailUrl'], data['imageUrl']];
        for (final candidate in candidates) {
          final value = candidate?.toString().trim() ?? '';
          if (value.isNotEmpty) {
            imageUrl = value;
            break;
          }
        }
      }
    } catch (_) {
      // Kart yine de gerçek içerik kimliğiyle gönderilir.
    }

    await ChatService.instance.sendSharedContent(
      threadId: threadId,
      otherUserId: targetUserId,
      sharedType: sharedType,
      sharedId: sourceId,
      title: title.trim().isEmpty ? 'Paylaşım' : title.trim(),
      imageUrl: imageUrl,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> users() =>
      _firestore.collection('users').limit(100).snapshots();
}
