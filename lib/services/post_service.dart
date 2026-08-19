import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostService {
  PostService._();
  static final PostService instance = PostService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> createPost({
    required File image,
    required String caption,
    required String spotName,
    double? latitude,
    double? longitude,
    List<String> taggedUserIds = const <String>[],
    List<String> taggedUserNames = const <String>[],
    String? eventId,
    String? eventTitle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Fotoğraf paylaşmak için giriş yapmalısın.');

    final cleanEventId = (eventId ?? '').trim();
    if (cleanEventId.isNotEmpty) {
      final event = await _firestore.collection('social_events').doc(cleanEventId).get();
      final data = event.data();
      if (data == null) throw Exception('Etkinlik bulunamadı.');
      final participants = (data['participantIds'] as List? ?? const []).map((e) => e.toString()).toList();
      if (!participants.contains(user.uid)) throw Exception('Bu etkinliğe yalnızca katılımcılar anı ekleyebilir.');
      final rawStart = data['startsAt'];
      final startsAt = rawStart is Timestamp ? rawStart.toDate() : DateTime.tryParse(rawStart?.toString() ?? '');
      if (startsAt != null && startsAt.isAfter(DateTime.now())) {
        throw Exception('Etkinlik başlamadan anı ekleyemezsin.');
      }
      if ((data['status'] ?? 'open').toString() == 'cancelled') {
        throw Exception('İptal edilen etkinliğe anı eklenemez.');
      }
    }

    final postRef = _firestore.collection('posts').doc();
    final lowerPath = image.path.toLowerCase();
    final extension = lowerPath.endsWith('.png') ? 'png' : 'jpg';
    final storageRef = _storage.ref().child('users/${user.uid}/posts/${postRef.id}.$extension');
    final metadata = SettableMetadata(contentType: extension == 'png' ? 'image/png' : 'image/jpeg');
    final uploadTask = await storageRef.putFile(image, metadata);
    final imageUrl = await uploadTask.ref.getDownloadURL();

    await postRef.set({
      'id': postRef.id,
      'userId': user.uid,
      'userName': user.displayName?.trim().isNotEmpty == true ? user.displayName : 'Fotoğrafçı',
      'userPhotoUrl': user.photoURL ?? '',
      'userEmail': user.email ?? '',
      'imageUrl': imageUrl,
      'storagePath': storageRef.fullPath,
      'caption': caption.trim(),
      'spotName': spotName.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'eventId': cleanEventId.isEmpty ? null : cleanEventId,
      'eventTitle': cleanEventId.isEmpty ? null : (eventTitle ?? '').trim(),
      'sourceType': cleanEventId.isEmpty ? 'post' : 'event_memory',
      'taggedUserIds': taggedUserIds.toSet().toList(),
      'taggedUserNames': taggedUserNames.toSet().toList(),
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> eventMemories(String eventId) =>
      _firestore.collection('posts').where('eventId', isEqualTo: eventId).limit(120).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> myPosts() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('posts').where('userId', isEqualTo: user.uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allPosts() =>
      _firestore.collection('posts').orderBy('createdAt', descending: true).snapshots();

  Future<void> updatePost({required String postId, required String caption, required String spotName}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    if (postId.trim().isEmpty) throw Exception('Gönderi bulunamadı.');
    final ref = _firestore.collection('posts').doc(postId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null || data['userId']?.toString() != user.uid) throw Exception('Bu gönderiyi düzenleme yetkin yok.');
    await ref.set({'caption': caption.trim(), 'spotName': spotName.trim(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> deletePost({required String postId, required String storagePath}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    final ref = _firestore.collection('posts').doc(postId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null || data['userId']?.toString() != user.uid) throw Exception('Bu gönderiyi silme yetkin yok.');
    await ref.delete();
    if (storagePath.isNotEmpty) {
      try { await _storage.ref().child(storagePath).delete(); } catch (_) {}
    }
  }
}
