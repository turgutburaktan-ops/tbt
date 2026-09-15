import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Route attachments use participant-only Storage paths, never public user URLs.
class RouteChatService {
  RouteChatService._();
  static final instance = RouteChatService._();
  DocumentReference<Map<String, dynamic>> plan(String id) =>
      FirebaseFirestore.instance.collection('travel_plans').doc(id);
  Map<String, dynamic> envelope(
    String text,
    String type,
    Map<String, dynamic>? reply,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    return {
      'senderId': user.uid,
      'senderName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Katılımcı',
      'senderPhoto': user.photoURL ?? '',
      'text': text,
      'type': type,
      if (reply != null) 'reply': reply,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> send(
    String id,
    String text, {
    Map<String, dynamic>? reply,
  }) async {
    if (text.trim().isEmpty || text.trim().length > 1000)
      throw Exception('Mesaj 1–1000 karakter olmalı.');
    await plan(id)
        .collection('messages')
        .add(envelope(text.trim(), 'text', reply));
  }

  Future<void> location(
    String id,
    String label,
    double latitude,
    double longitude, {
    Map<String, dynamic>? reply,
  }) async {
    await plan(id).collection('messages').add({
      ...envelope(
        label.isEmpty ? 'Paylaşılan konum' : label,
        'location',
        reply,
      ),
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<void> audio(
    String id,
    Uint8List bytes,
    int durationMs, {
    Map<String, dynamic>? reply,
  }) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024)
      throw Exception('Ses kaydı en fazla 20 MB olabilir.');
    final data = envelope('Sesli mesaj', 'audio', reply);
    final doc = plan(id).collection('messages').doc();
    final ref = FirebaseStorage.instance.ref(
      'route_chat/$id/${data['senderId']}/${doc.id}/audio.m4a',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'audio/mp4'));
    // Keep uploaded bytes on an ambiguous Firestore failure: the write may have committed.
    await doc.set({
      ...data,
      'storagePath': ref.fullPath,
      'durationMs': durationMs,
    });
  }

  Future<void> media(
    String id,
    XFile file, {
    required bool addToAlbum,
    required bool allowExport,
    Map<String, dynamic>? reply,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final video = ['mp4', 'mov'].contains(ext);
    if (![
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
      'mp4',
      'mov',
    ].contains(ext))
      throw Exception('Bu dosya türü desteklenmiyor.');
    final size = await file.length();
    if (size == 0 || size > (video ? 100 : 15) * 1024 * 1024)
      throw Exception(
        video
            ? 'Video en fazla 100 MB olabilir.'
            : 'Fotoğraf en fazla 15 MB olabilir.',
      );
    final type = video ? 'video' : 'image';
    final data = envelope(video ? 'Video' : 'Fotoğraf', type, reply);
    final root = plan(id);
    final doc = root.collection('messages').doc();
    final extension = ext == 'jpeg' ? 'jpg' : ext;
    final mime = video
        ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
        : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
    final ref = FirebaseStorage.instance.ref(
      'route_albums/$id/${data['senderId']}/${doc.id}/media.$extension',
    );
    await ref.putFile(File(file.path), SettableMetadata(contentType: mime));
    final batch = FirebaseFirestore.instance.batch();
    batch.set(doc, {
      ...data,
      'storagePath': ref.fullPath,
      'inAlbum': addToAlbum,
    });
    if (addToAlbum)
      batch.set(root.collection('album').doc(doc.id), {
        'ownerId': data['senderId'],
        'ownerName': data['senderName'],
        'storagePath': ref.fullPath,
        'thumbnailPath': '',
        'kind': type,
        'allowExport': allowExport,
        'createdAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
  }
}
