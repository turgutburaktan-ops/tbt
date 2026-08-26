import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'app_notification_service.dart';
import 'video_media_service.dart';

class PostService {
  PostService._();
  static final PostService instance = PostService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Map<String, dynamic> _postBase({
    required String id,
    required User user,
    required String caption,
    required String spotName,
    required double? latitude,
    required double? longitude,
    required List<String> taggedUserIds,
    required List<String> taggedUserNames,
    String businessVenueKey = '',
    String businessVenueName = '',
  }) {
    return {
      'id': id,
      'userId': user.uid,
      'userName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : 'Fotoğrafçı',
      'userPhotoUrl': user.photoURL ?? '',
      'userEmail': user.email ?? '',
      'caption': caption.trim(),
      'spotName': spotName.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'taggedUserIds': taggedUserIds.toSet().toList(),
      'taggedUserNames': taggedUserNames.toSet().toList(),
      'likesCount': 0,
      'commentsCount': 0,
      'sourceType': 'post',
      'businessVenueKey': businessVenueKey,
      'businessVenueName': businessVenueName,
      // Visitor check-ins may reference a venue but must never impersonate the
      // verified business account. Official business publishing is separately
      // protected by Firestore ownership checks.
      'businessOfficial': false,
      // Keep the legacy field used by business profile queries in sync.
      'venueKey': businessVenueKey,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> createPost({
    required File image,
    required String caption,
    required String spotName,
    double? latitude,
    double? longitude,
    List<String> taggedUserIds = const <String>[],
    List<String> taggedUserNames = const <String>[],
    String businessVenueKey = '',
    String businessVenueName = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception('Fotoğraf paylaşmak için giriş yapmalısın.');

    if (!await image.exists())
      throw Exception('Paylaşılacak fotoğraf bulunamadı.');
    final sourceBytes = await image.length();
    if (sourceBytes <= 0) throw Exception('Fotoğraf dosyası boş.');
    if (sourceBytes > 40 * 1024 * 1024) {
      throw Exception('Fotoğraf 40 MB sınırını aşıyor.');
    }

    final postRef = _firestore.collection('posts').doc();
    final lowerPath = image.path.toLowerCase();
    final extension = lowerPath.endsWith('.png') ? 'png' : 'jpg';
    final storageRef = _storage.ref().child(
      'users/${user.uid}/posts/${postRef.id}.$extension',
    );
    final metadata = SettableMetadata(
      contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
    );
    final uploadTask = await storageRef.putFile(image, metadata);
    if (uploadTask.totalBytes <= 0 || uploadTask.bytesTransferred <= 0) {
      throw Exception('Fotoğraf Storage alanına eksik yüklendi.');
    }
    final imageUrl = await uploadTask.ref.getDownloadURL();

    await postRef.set({
      ..._postBase(
        id: postRef.id,
        user: user,
        caption: caption,
        spotName: spotName,
        latitude: latitude,
        longitude: longitude,
        taggedUserIds: taggedUserIds,
        taggedUserNames: taggedUserNames,
        businessVenueKey: businessVenueKey,
        businessVenueName: businessVenueName,
      ),
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

  Future<void> createVideoPost({
    required File video,
    required String caption,
    required String spotName,
    double? latitude,
    double? longitude,
    List<String> taggedUserIds = const <String>[],
    List<String> taggedUserNames = const <String>[],
    String businessVenueKey = '',
    String businessVenueName = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Video paylaşmak için giriş yapmalısın.');

    final prepared = await VideoMediaService.instance.prepare(
      video,
      maxDuration: const Duration(seconds: 60),
    );
    final postRef = _firestore.collection('posts').doc();
    final videoRef = _storage.ref().child(
      'users/${user.uid}/posts/${postRef.id}.mp4',
    );
    final thumbRef = _storage.ref().child(
      'users/${user.uid}/posts/${postRef.id}_thumb.jpg',
    );

    final videoUpload = await videoRef.putFile(
      prepared.video,
      SettableMetadata(contentType: 'video/mp4'),
    );
    if (videoUpload.bytesTransferred <= 0) {
      throw Exception('Video yüklenemedi.');
    }
    final thumbUpload = await thumbRef.putFile(
      prepared.thumbnail,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    if (thumbUpload.bytesTransferred <= 0) {
      try {
        await videoRef.delete();
      } catch (_) {}
      throw Exception('Video önizlemesi yüklenemedi.');
    }

    final videoUrl = await videoUpload.ref.getDownloadURL();
    final thumbnailUrl = await thumbUpload.ref.getDownloadURL();
    await postRef.set({
      ..._postBase(
        id: postRef.id,
        user: user,
        caption: caption,
        spotName: spotName,
        latitude: latitude,
        longitude: longitude,
        taggedUserIds: taggedUserIds,
        taggedUserNames: taggedUserNames,
        businessVenueKey: businessVenueKey,
        businessVenueName: businessVenueName,
      ),
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

  Future<Map<String, dynamic>> _eventContext(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Anı eklemek için giriş yapmalısın.');
    final event = await _firestore
        .collection('social_events')
        .doc(eventId)
        .get();
    final eventData = event.data();
    if (eventData == null) throw Exception('Etkinlik bulunamadı.');
    final participants = (eventData['participantIds'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    if (!participants.contains(user.uid)) {
      throw Exception('Bu etkinliğe yalnızca katılımcılar anı ekleyebilir.');
    }
    final rawStart = eventData['startsAt'];
    final startsAt = rawStart is Timestamp
        ? rawStart.toDate()
        : DateTime.tryParse(rawStart?.toString() ?? '');
    if (startsAt != null && startsAt.isAfter(DateTime.now())) {
      throw Exception('Etkinlik başlamadan anı ekleyemezsin.');
    }
    if ((eventData['status'] ?? 'open').toString() == 'cancelled') {
      throw Exception('İptal edilen etkinliğe anı eklenemez.');
    }
    return {'user': user, 'eventData': eventData, 'participants': participants};
  }

  Future<void> createEventMemory({
    required File image,
    required String caption,
    required String eventId,
    required String eventTitle,
    required String spotName,
    double? latitude,
    double? longitude,
  }) async {
    final context = await _eventContext(eventId);
    final user = context['user'] as User;
    final eventData = context['eventData'] as Map<String, dynamic>;
    final participants = context['participants'] as List<String>;

    if (!await image.exists() || await image.length() <= 0) {
      throw Exception('Anı fotoğrafı bulunamadı.');
    }

    final memoryRef = _firestore.collection('event_memories').doc();
    final lowerPath = image.path.toLowerCase();
    final extension = lowerPath.endsWith('.png') ? 'png' : 'jpg';
    final storageRef = _storage.ref().child(
      'users/${user.uid}/event_memories/$eventId/${memoryRef.id}.$extension',
    );
    final metadata = SettableMetadata(
      contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
    );
    final uploadTask = await storageRef.putFile(image, metadata);
    final imageUrl = await uploadTask.ref.getDownloadURL();
    await _saveEventMemory(
      memoryRef: memoryRef,
      user: user,
      eventData: eventData,
      participants: participants,
      eventId: eventId,
      eventTitle: eventTitle,
      caption: caption,
      spotName: spotName,
      latitude: latitude,
      longitude: longitude,
      media: {
        'mediaType': 'image',
        'imageUrl': imageUrl,
        'storagePath': storageRef.fullPath,
        'videoUrl': '',
        'videoStoragePath': '',
        'thumbnailUrl': '',
        'thumbnailStoragePath': '',
        'durationMs': 0,
      },
    );
  }

  Future<void> createEventVideoMemory({
    required File video,
    required String caption,
    required String eventId,
    required String eventTitle,
    required String spotName,
    double? latitude,
    double? longitude,
  }) async {
    final context = await _eventContext(eventId);
    final user = context['user'] as User;
    final eventData = context['eventData'] as Map<String, dynamic>;
    final participants = context['participants'] as List<String>;
    final prepared = await VideoMediaService.instance.prepare(
      video,
      maxDuration: const Duration(seconds: 60),
    );

    final memoryRef = _firestore.collection('event_memories').doc();
    final videoRef = _storage.ref().child(
      'users/${user.uid}/event_memories/$eventId/${memoryRef.id}.mp4',
    );
    final thumbRef = _storage.ref().child(
      'users/${user.uid}/event_memories/$eventId/${memoryRef.id}_thumb.jpg',
    );
    final videoUpload = await videoRef.putFile(
      prepared.video,
      SettableMetadata(contentType: 'video/mp4'),
    );
    final thumbUpload = await thumbRef.putFile(
      prepared.thumbnail,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    if (videoUpload.bytesTransferred <= 0 ||
        thumbUpload.bytesTransferred <= 0) {
      throw Exception('Etkinlik videosu yüklenemedi.');
    }
    final videoUrl = await videoUpload.ref.getDownloadURL();
    final thumbnailUrl = await thumbUpload.ref.getDownloadURL();

    await _saveEventMemory(
      memoryRef: memoryRef,
      user: user,
      eventData: eventData,
      participants: participants,
      eventId: eventId,
      eventTitle: eventTitle,
      caption: caption,
      spotName: spotName,
      latitude: latitude,
      longitude: longitude,
      media: {
        'mediaType': 'video',
        'imageUrl': thumbnailUrl,
        'storagePath': thumbRef.fullPath,
        'videoUrl': videoUrl,
        'videoStoragePath': videoRef.fullPath,
        'thumbnailUrl': thumbnailUrl,
        'thumbnailStoragePath': thumbRef.fullPath,
        'durationMs': prepared.durationMs,
      },
    );
  }

  Future<void> _saveEventMemory({
    required DocumentReference<Map<String, dynamic>> memoryRef,
    required User user,
    required Map<String, dynamic> eventData,
    required List<String> participants,
    required String eventId,
    required String eventTitle,
    required String caption,
    required String spotName,
    required double? latitude,
    required double? longitude,
    required Map<String, dynamic> media,
  }) async {
    final userName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : 'Katılımcı';
    final visibility = (eventData['visibility'] ?? 'public').toString();
    final memoryData = <String, dynamic>{
      'id': memoryRef.id,
      'eventId': eventId,
      'eventTitle': eventTitle.trim(),
      'eventVisibility': visibility,
      'userId': user.uid,
      'userName': userName,
      'userPhotoUrl': user.photoURL ?? '',
      ...media,
      'caption': caption.trim(),
      'spotName': spotName.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await memoryRef.set(memoryData);

    if (visibility == 'public') {
      await _firestore.collection('posts').doc(memoryRef.id).set({
        ...memoryData,
        'sourceType': 'event_memory',
        'likesCount': 0,
        'commentsCount': 0,
      });
    }

    try {
      await AppNotificationService.instance.notifyUsers(
        userIds: participants.where((id) => id != user.uid),
        type: 'event_memory',
        title: '$userName etkinliğe yeni bir anı ekledi',
        body: eventTitle.trim(),
        sourceId: eventId,
        actorId: user.uid,
      );
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> eventMemories(String eventId) =>
      _firestore
          .collection('event_memories')
          .where('eventId', isEqualTo: eventId)
          .limit(120)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> myPosts() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allPosts() => _firestore
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .snapshots();

  Future<void> updatePost({
    required String postId,
    required String caption,
    required String spotName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    if (postId.trim().isEmpty) throw Exception('Gönderi bulunamadı.');
    final ref = _firestore.collection('posts').doc(postId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null || data['userId']?.toString() != user.uid) {
      throw Exception('Bu gönderiyi düzenleme yetkin yok.');
    }
    await ref.set({
      'caption': caption.trim(),
      'spotName': spotName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deletePost({
    required String postId,
    required String storagePath,
    String videoStoragePath = '',
    String thumbnailStoragePath = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    final ref = _firestore.collection('posts').doc(postId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null || data['userId']?.toString() != user.uid) {
      throw Exception('Bu gönderiyi silme yetkin yok.');
    }
    await ref.delete();
    final paths = <String>{storagePath, videoStoragePath, thumbnailStoragePath}
      ..removeWhere((path) => path.trim().isEmpty);
    for (final path in paths) {
      try {
        await _storage.ref().child(path).delete();
      } catch (_) {}
    }
  }
}
