import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MultiPhotoPostService {
  MultiPhotoPostService._();
  static final MultiPhotoPostService instance = MultiPhotoPostService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createPost({
    required List<File> images,
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
    if (user == null) throw Exception('Fotoğraf paylaşmak için giriş yapmalısın.');
    if (images.isEmpty) throw Exception('En az bir fotoğraf seçmelisin.');
    if (images.length > 10) throw Exception('Bir gönderide en fazla 10 fotoğraf paylaşabilirsin.');

    for (final image in images) {
      if (!await image.exists() || await image.length() <= 0) {
        throw Exception('Seçilen fotoğraflardan biri bulunamadı.');
      }
      if (await image.length() > 40 * 1024 * 1024) {
        throw Exception('Fotoğraflardan biri 40 MB sınırını aşıyor.');
      }
    }

    final postRef = _firestore.collection('posts').doc();
    final urls = <String>[];
    final paths = <String>[];
    try {
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final lower = image.path.toLowerCase();
        final extension = lower.endsWith('.png') ? 'png' : 'jpg';
        final ref = _storage.ref().child(
          'users/${user.uid}/posts/${postRef.id}/image_${i + 1}.$extension',
        );
        final task = await ref.putFile(
          image,
          SettableMetadata(
            contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
        if (task.bytesTransferred <= 0) throw Exception('Fotoğraf yüklenemedi.');
        urls.add(await task.ref.getDownloadURL());
        paths.add(ref.fullPath);
      }

      await postRef.set({
        'id': postRef.id,
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
        'businessOfficial': false,
        'venueKey': businessVenueKey,
        'mediaType': 'image',
        // Legacy fields keep old clients and existing feed code compatible.
        'imageUrl': urls.first,
        'storagePath': paths.first,
        // New carousel fields preserve the selected order.
        'mediaUrls': urls,
        'mediaStoragePaths': paths,
        'mediaCount': urls.length,
        'videoUrl': '',
        'videoStoragePath': '',
        'thumbnailUrl': '',
        'thumbnailStoragePath': '',
        'durationMs': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      for (final path in paths) {
        try {
          await _storage.ref(path).delete();
        } catch (_) {}
      }
      rethrow;
    }
  }
}
