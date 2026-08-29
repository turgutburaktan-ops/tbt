import 'dart:async';
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
  final Map<String, DateTime> _recentViews = <String, DateTime>{};

  void _enforceStoryCreateCooldown() {
    final now = DateTime.now();
    final previous = _lastStoryCreateAt;
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 3)) {
      throw Exception(
        'Çok hızlı story paylaşımı yapıyorsun. Birkaç saniye bekle.',
      );
    }
    _lastStoryCreateAt = now;
  }

  void _enforceInteractionCooldown(String storyId, String action) {
    final now = DateTime.now();
    final key = '$storyId:$action';
    final previous = _lastInteractionAt[key];
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 700)) {
      throw Exception('Çok hızlı işlem yapıyorsun. Lütfen tekrar dene.');
    }
    _lastInteractionAt[key] = now;
  }

  void _ensureActiveStory(AppStory story) {
    if (!story.isActive) throw Exception('Bu story artık aktif değil.');
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

  Stream<List<AppStory>> watchArchive() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('story_archive')
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final stories = snapshot.docs.map(AppStory.fromDocument).toList();
          stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return stories;
        });
  }

  Future<void> syncLegacyStoriesToArchive() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final stories = await _firestore
        .collection('stories')
        .where('userId', isEqualTo: user.uid)
        .limit(200)
        .get();
    if (stories.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final story in stories.docs) {
      final archiveRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('story_archive')
          .doc(story.id);
      batch.set(archiveRef, {
        ...story.data(),
        'id': story.id,
        'userId': user.uid,
        'archivedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
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
    final storageRef = _storage.ref().child(
      'users/${user.uid}/stories/${storyRef.id}.$extension',
    );
    try {
      final upload = await storageRef
          .putFile(
            image,
            SettableMetadata(
              contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            ),
          )
          .timeout(const Duration(seconds: 30));
      if (upload.bytesTransferred <= 0) {
        throw Exception('Story fotoğrafı yüklenemedi.');
      }
      final imageUrl = await storageRef
          .getDownloadURL()
          .timeout(const Duration(seconds: 8));
      final storyData = <String, dynamic>{
        ..._baseStoryData(user, storyRef.id),
        'mediaType': 'image',
        'imageUrl': imageUrl,
        'storagePath': storageRef.fullPath,
        'videoUrl': '',
        'videoStoragePath': '',
        'thumbnailUrl': '',
        'thumbnailStoragePath': '',
        'durationMs': 0,
      };
      final batch = _firestore.batch();
      batch.set(storyRef, storyData);
      batch.set(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('story_archive')
            .doc(storyRef.id),
        {...storyData, 'archivedAt': FieldValue.serverTimestamp()},
      );
      await batch.commit().timeout(const Duration(seconds: 8));
    } catch (_) {
      unawaited(_deleteStorageQuietly(storageRef));
      rethrow;
    }
  }

  Future<void> createVideoStory(File sourceVideo) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Story paylaşmak için giriş yapmalısın.');
    _enforceStoryCreateCooldown();

    final prepared = await VideoMediaService.instance
        .prepare(sourceVideo, maxDuration: const Duration(seconds: 15))
        .timeout(const Duration(seconds: 45));
    final storyRef = _firestore.collection('stories').doc();
    final videoRef = _storage.ref().child(
      'users/${user.uid}/stories/${storyRef.id}.mp4',
    );
    final thumbRef = _storage.ref().child(
      'users/${user.uid}/stories/${storyRef.id}_thumb.jpg',
    );

    try {
      final videoUpload = await videoRef
          .putFile(prepared.video, SettableMetadata(contentType: 'video/mp4'))
          .timeout(const Duration(seconds: 45));
      if (videoUpload.bytesTransferred <= 0) {
        throw Exception('Story videosu yüklenemedi.');
      }

      final thumbUpload = await thumbRef
          .putFile(
            prepared.thumbnail,
            SettableMetadata(contentType: 'image/jpeg'),
          )
          .timeout(const Duration(seconds: 20));
      if (thumbUpload.bytesTransferred <= 0) {
        throw Exception('Story video önizlemesi yüklenemedi.');
      }

      final urls = await Future.wait([
        videoRef.getDownloadURL().timeout(const Duration(seconds: 8)),
        thumbRef.getDownloadURL().timeout(const Duration(seconds: 8)),
      ]);
      final videoUrl = urls[0];
      final thumbnailUrl = urls[1];
      final storyData = <String, dynamic>{
        ..._baseStoryData(user, storyRef.id),
        'mediaType': 'video',
        'imageUrl': thumbnailUrl,
        'storagePath': thumbRef.fullPath,
        'videoUrl': videoUrl,
        'videoStoragePath': videoRef.fullPath,
        'thumbnailUrl': thumbnailUrl,
        'thumbnailStoragePath': thumbRef.fullPath,
        'durationMs': prepared.durationMs,
      };
      final batch = _firestore.batch();
      batch.set(storyRef, storyData);
      batch.set(
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('story_archive')
            .doc(storyRef.id),
        {...storyData, 'archivedAt': FieldValue.serverTimestamp()},
      );
      await batch.commit().timeout(const Duration(seconds: 8));
    } catch (_) {
      unawaited(_deleteStorageQuietly(videoRef));
      unawaited(_deleteStorageQuietly(thumbRef));
      rethrow;
    }
  }

  Future<void> _deleteStorageQuietly(Reference reference) async {
    try {
      await reference.delete().timeout(const Duration(seconds: 6));
    } catch (_) {}
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

  Stream<Set<String>> watchViewedStoryIds(Iterable<String> storyIds) {
    final user = _auth.currentUser;
    final ids = storyIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (user == null || ids.isEmpty) return Stream.value(<String>{});
    final Map<
      String,
      StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
    > controllers = {};
    final viewed = <String>{};
    late final StreamController<Set<String>> controller;
    controller = StreamController<Set<String>>.broadcast(
      onListen: () {
        for (final id in ids) {
          controllers[id] = _interactionRef(id, user.uid).snapshots().listen(
            (doc) {
              if (doc.exists && doc.data()?['viewedAt'] != null) {
                viewed.add(id);
              } else {
                viewed.remove(id);
              }
              if (!controller.isClosed) controller.add(Set<String>.from(viewed));
            },
            onError: (_) {},
          );
        }
        controller.add(Set<String>.from(viewed));
      },
      onCancel: () async {
        for (final subscription in controllers.values) {
          await subscription.cancel();
        }
        controllers.clear();
      },
    );
    return controller.stream;
  }

  Future<void> recordView(AppStory story) async {
    final user = _auth.currentUser;
    if (user == null || user.uid == story.userId || !story.isActive) return;
    final key = '${user.uid}:${story.id}';
    final now = DateTime.now();
    final previous = _recentViews[key];
    if (previous != null &&
        now.difference(previous) < const Duration(minutes: 10)) {
      return;
    }
    _recentViews[key] = now;
    try {
      await _interactionRef(story.id, user.uid).set({
        ..._actorData(user),
        'viewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
    } catch (_) {
      _recentViews.remove(key);
    }
  }

  Stream<Map<String, dynamic>> watchMyInteraction(String storyId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const <String, dynamic>{});
    return _interactionRef(
      storyId,
      user.uid,
    ).snapshots().map((doc) => doc.data() ?? const <String, dynamic>{});
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
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 7));
    if (liked) {
      unawaited(_notifyQuietly(
        userId: story.userId,
        type: 'story_like',
        title: '${_actorName(user)} storyini beğendi',
        body: 'Story etkileşimlerini görmek için dokun.',
        sourceId: story.id,
        actorId: user.uid,
      ));
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
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 7));
    unawaited(_notifyQuietly(
      userId: story.userId,
      type: 'story_reaction',
      title: '${_actorName(user)} storyine tepki verdi',
      body: clean,
      sourceId: story.id,
      actorId: user.uid,
    ));
  }

  Future<void> _notifyQuietly({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String sourceId,
    required String actorId,
  }) async {
    try {
      await AppNotificationService.instance
          .notifyUser(
            userId: userId,
            type: type,
            title: title,
            body: body,
            sourceId: sourceId,
            actorId: actorId,
          )
          .timeout(const Duration(seconds: 6));
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

    try {
      await _interactionRef(story.id, user.uid).set({
        ..._actorData(user),
        'message': clean,
        'messageAt': FieldValue.serverTimestamp(),
        'viewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<void> deleteStory(AppStory story) async {
    final user = _auth.currentUser;
    if (user == null || story.userId != user.uid) return;
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('stories').doc(story.id));
    batch.delete(
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('story_archive')
          .doc(story.id),
    );
    await batch.commit().timeout(const Duration(seconds: 7));
    final paths = <String>{
      story.storagePath,
      story.videoStoragePath,
      story.thumbnailStoragePath,
    }..removeWhere((path) => path.trim().isEmpty);
    await Future.wait(
      paths.map((path) => _deleteStorageQuietly(_storage.ref().child(path))),
    );
  }

  Future<void> repostArchivedStory(AppStory story) async {
    final user = _auth.currentUser;
    if (user == null || story.userId != user.uid) {
      throw Exception('Bu Story’yi yeniden paylaşma yetkin yok.');
    }
    _enforceStoryCreateCooldown();
    final storyRef = _firestore.collection('stories').doc();
    await storyRef.set({
      ..._baseStoryData(user, storyRef.id),
      'mediaType': story.mediaType,
      'imageUrl': story.imageUrl,
      'storagePath': story.storagePath,
      'videoUrl': story.videoUrl,
      'videoStoragePath': story.videoStoragePath,
      'thumbnailUrl': story.thumbnailUrl,
      'thumbnailStoragePath': story.thumbnailStoragePath,
      'durationMs': story.durationMs,
      'repostedFromStoryId': story.id,
    }).timeout(const Duration(seconds: 8));
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('story_archive')
        .doc(story.id)
        .set({
          'lastRepostedAt': FieldValue.serverTimestamp(),
          'repostCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
  }
}
