import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_story.dart';
import 'app_notification_service.dart';
import 'chat_service.dart';
import 'content_moderation_service.dart';
import 'video_media_service.dart';

class StoryService {
  StoryService._();

  static final instance = StoryService._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DateTime? _lastStoryCreateAt;
  final Map<String, DateTime> _lastInteractionAt = <String, DateTime>{};

  void _enforceStoryCreateCooldown() {
    final now = DateTime.now();
    final previous = _lastStoryCreateAt;
    if (previous != null && now.difference(previous) < const Duration(seconds: 3)) {
      throw Exception('Çok hızlı story paylaşımı yapıyorsun. Birkaç saniye bekle.');
    }
    _lastStoryCreateAt = now;
  }

  void _enforceInteractionCooldown(String storyId, String action) {
    final now = DateTime.now();
    final key = '$storyId:$action';
    final previous = _lastInteractionAt[key];
    if (previous != null && now.difference(previous) < const Duration(milliseconds: 700)) {
      throw Exception('Çok hızlı işlem yapıyorsun. Lütfen tekrar dene.');
    }
    _lastInteractionAt[key] = now;
  }

  void _ensureActiveStory(AppStory story) {
    if (!story.isActive) {
      throw Exception('Bu story artık aktif değil.');
    }
  }

  Stream<List<AppStory>> watchActive() {
    return _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(150)
        .snapshots()
        .map((snapshot) {
      final stories = snapshot.docs
          .map(AppStory.fromDocument)
          .where((story) => story.userId.isNotEmpty && story.isActive)
          .toList();
      stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return stories;
    });
  }

  Stream<List<AppStory>> watchActiveForUser(String userId) {
    return watchActive().map(
      (stories) => stories
          .where((story) => story.userId == userId)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> _baseStoryData(User user, String storyId) {
    final now = DateTime.now();
    return {
      'id': storyId,
      'userId': user.uid,
      'userName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : 'TBT kullanıcısı',
      'userPhotoUrl': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    };
  }

  Future<void> createStory(File image) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Story paylaşmak için giriş yapmalısın.');
    _enforceStoryCreateCooldown();
    if (!await image.exists() || await image.length() == 0) {
      throw Exception('Paylaşılacak fotoğraf bulunamadı.');
    }
    if (await image.length() > 15 * 1024 * 1024) {
      throw Exception('Fotoğraf 15 MB sınırını aşıyor.');
    }

    final storyRef = _firestore.collection('stories').doc();
    final extension = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final storageRef = _storage
        .ref()
        .child('users/${user.uid}/stories/${storyRef.id}.$extension');
    final metadata = SettableMetadata(
      contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
    );
    final upload = await storageRef.putFile(image, metadata);
    if (upload.bytesTransferred <= 0) {
      throw Exception('Story fotoğrafı yüklenemedi.');
    }
    final imageUrl = await upload.ref.getDownloadURL();
    await storyRef.set({
      ..._baseStoryData(user, storyRef.id),
      'mediaType': 'image',
      'imageUrl': imageUrl,
      'storagePath': storageRef.fullPath,
      'videoUrl': '',
      'videoStoragePath': '',
      'thumbnailUrl': '',
      'thumbnailStoragePath': '',
      'durationMs': 0,
    });
  }

  Future<void> createVideoStory(File sourceVideo) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Story paylaşmak için giriş yapmalısın.');
    _enforceStoryCreateCooldown();

    final prepared = await VideoMediaService.instance.prepare(
      sourceVideo,
      maxDuration: const Duration(seconds: 15),
    );
    final storyRef = _firestore.collection('stories').doc();
    final videoRef = _storage
        .ref()
        .child('users/${user.uid}/stories/${storyRef.id}.mp4');
    final thumbRef = _storage
        .ref()
        .child('users/${user.uid}/stories/${storyRef.id}_thumb.jpg');

    final videoUpload = await videoRef.putFile(
      prepared.video,
      SettableMetadata(contentType: 'video/mp4'),
    );
    if (videoUpload.bytesTransferred <= 0) {
      throw Exception('Story videosu yüklenemedi.');
    }
    final thumbUpload = await thumbRef.putFile(
      prepared.thumbnail,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    if (thumbUpload.bytesTransferred <= 0) {
      try {
        await videoRef.delete();
      } catch (_) {}
      throw Exception('Story video önizlemesi yüklenemedi.');
    }

    final videoUrl = await videoUpload.ref.getDownloadURL();
    final thumbnailUrl = await thumbUpload.ref.getDownloadURL();
    await storyRef.set({
      ..._baseStoryData(user, storyRef.id),
      'mediaType': 'video',
      'imageUrl': thumbnailUrl,
      'storagePath': thumbRef.fullPath,
      'videoUrl': videoUrl,
      'videoStoragePath': videoRef.fullPath,
      'thumbnailUrl': thumbnailUrl,
      'thumbnailStoragePath': thumbRef.fullPath,
      'durationMs': prepared.durationMs,
    });
  }

  DocumentReference<Map<String, dynamic>> _interactionRef(
    String storyId,
    String userId,
  ) {
    return _firestore
        .collection('stories')
        .doc(storyId)
        .collection('interactions')
        .doc(userId);
  }

  Map<String, dynamic> _actorData(User user) => {
        'userId': user.uid,
        'userName': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'TBT kullanıcısı',
        'userPhotoUrl': user.photoURL ?? '',
      };

  String _actorName(User user) => (user.displayName ?? '').trim().isNotEmpty
      ? user.displayName!.trim()
      : 'Bir kullanıcı';

  Future<void> recordView(AppStory story) async {
    final user = _auth.currentUser;
    if (user == null || user.uid == story.userId || !story.isActive) return;
    await _interactionRef(story.id, user.uid).set({
      ..._actorData(user),
      'viewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> watchMyInteraction(String storyId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const <String, dynamic>{});
    return _interactionRef(storyId, user.uid).snapshots().map(
          (doc) => doc.data() ?? const <String, dynamic>{},
        );
  }

  Stream<List<Map<String, dynamic>>> watchInteractions(AppStory story) {
    final user = _auth.currentUser;
    if (user == null || user.uid != story.userId) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }
    return _firestore
        .collection('stories')
        .doc(story.id)
        .collection('interactions')
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
      items.sort((a, b) {
        final at = a['updatedAt'];
        final bt = b['updatedAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });
      return items;
    });
  }

  Future<void> setLiked(AppStory story, bool liked) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Story beğenmek için giriş yapmalısın.');
    if (user.uid == story.userId) return;
    _ensureActiveStory(story);
    _enforceInteractionCooldown(story.id, 'like');
    await _interactionRef(story.id, user.uid).set({
      ..._actorData(user),
      'liked': liked,
      'viewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (liked) {
      try {
        await AppNotificationService.instance.notifyUser(
          userId: story.userId,
          type: 'story_like',
          title: '${_actorName(user)} storyini beğendi',
          body: 'Story etkileşimlerini görmek için dokun.',
          sourceId: story.id,
          actorId: user.uid,
        );
      } catch (_) {}
    }
  }

  Future<void> setReaction(AppStory story, String emoji) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Tepki göndermek için giriş yapmalısın.');
    if (user.uid == story.userId) return;
    _ensureActiveStory(story);
    _enforceInteractionCooldown(story.id, 'reaction');
    final clean = emoji.trim();
    if (clean.isEmpty || clean.length > 8) return;
    await _interactionRef(story.id, user.uid).set({
      ..._actorData(user),
      'reaction': clean,
      'viewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    try {
      await AppNotificationService.instance.notifyUser(
        userId: story.userId,
        type: 'story_reaction',
        title: '${_actorName(user)} storyine tepki verdi',
        body: clean,
        sourceId: story.id,
        actorId: user.uid,
      );
    } catch (_) {}
  }

  Future<void> sendReply(AppStory story, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Mesaj göndermek için giriş yapmalısın.');
    if (user.uid == story.userId) return;
    _ensureActiveStory(story);
    _enforceInteractionCooldown(story.id, 'reply');
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (clean.length > 500) {
      throw Exception('Story mesajı en fazla 500 karakter olabilir.');
    }
    ContentModerationService.instance.enforce(clean);

    await _interactionRef(story.id, user.uid).set({
      ..._actorData(user),
      'message': clean,
      'messageAt': FieldValue.serverTimestamp(),
      'viewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final threadId = await ChatService.instance.ensureDirectThread(
      story.userId,
      sourceType: 'story',
      sourceId: story.id,
    );
    await ChatService.instance.sendMessage(
      threadId: threadId,
      otherUserId: story.userId,
      text: 'Story yanıtı: $clean',
    );
  }

  Future<void> deleteStory(AppStory story) async {
    final user = _auth.currentUser;
    if (user == null || story.userId != user.uid) return;
    await _firestore.collection('stories').doc(story.id).delete();
    final paths = <String>{
      story.storagePath,
      story.videoStoragePath,
      story.thumbnailStoragePath,
    }..removeWhere((path) => path.trim().isEmpty);
    for (final path in paths) {
      try {
        await _storage.ref().child(path).delete();
      } catch (_) {}
    }
  }
}
