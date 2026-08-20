import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_story.dart';

class StoryService {
  StoryService._();

  static final instance = StoryService._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

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
      stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return stories;
    });
  }

  Future<void> createStory(File image) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Story paylaşmak için giriş yapmalısın.');
    if (!await image.exists() || await image.length() == 0) {
      throw Exception('Paylaşılacak fotoğraf bulunamadı.');
    }
    if (await image.length() > 40 * 1024 * 1024) {
      throw Exception('Fotoğraf 40 MB sınırını aşıyor.');
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
    final now = DateTime.now();
    await storyRef.set({
      'id': storyRef.id,
      'userId': user.uid,
      'userName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : 'TBT kullanıcısı',
      'userPhotoUrl': user.photoURL ?? '',
      'imageUrl': imageUrl,
      'storagePath': storageRef.fullPath,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
    });
  }

  Future<void> deleteStory(AppStory story) async {
    final user = _auth.currentUser;
    if (user == null || story.userId != user.uid) return;
    await _firestore.collection('stories').doc(story.id).delete();
    if (story.storagePath.isNotEmpty) {
      try {
        await _storage.ref().child(story.storagePath).delete();
      } catch (_) {}
    }
  }
}
