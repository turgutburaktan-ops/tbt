import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'e2ee_service.dart';
import 'video_media_service.dart';

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
    if (user == null) throw StateError('Giriş yapmalısın.');
    return {
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Katılımcı',
      'senderPhoto': user.photoURL ?? '',
      'text': text,
      'type': type,
      if (reply != null) 'reply': reply,
    };
  }

  Future<void> _send(
    String id,
    Map<String, dynamic> content, {
    String? messageId,
  }) => E2eeService.instance.send(
    id,
    messageId ?? plan(id).collection('messages').doc().id,
    content,
    scope: 'route',
  );
  Future<void> send(
    String id,
    String text, {
    Map<String, dynamic>? reply,
  }) async {
    if (text.trim().isEmpty || text.trim().length > 1000)
      throw StateError('Mesaj 1–1000 karakter olmalı.');
    await _send(id, envelope(text.trim(), 'text', reply));
  }

  Future<void> location(
    String id,
    String label,
    double latitude,
    double longitude, {
    Map<String, dynamic>? reply,
  }) => _send(id, {
    ...envelope(label.isEmpty ? 'Paylaşılan konum' : label, 'location', reply),
    'latitude': latitude,
    'longitude': longitude,
  });
  Future<void> audio(
    String id,
    Uint8List bytes,
    int durationMs, {
    Map<String, dynamic>? reply,
  }) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024)
      throw StateError('Ses kaydı en fazla 20 MB olabilir.');
    final message = plan(id).collection('messages').doc().id;
    final path = await E2eeService.instance.upload(
      id,
      message,
      bytes,
      contentType: 'audio/mp4',
      scope: 'route',
    );
    await _send(id, {
      ...envelope('Sesli mesaj', 'audio', reply),
      'storagePath': path,
      'durationMs': durationMs,
    }, messageId: message);
  }

  Future<void> media(
    String id,
    XFile file, {
    required bool addToAlbum,
    required bool allowExport,
    Map<String, dynamic>? reply,
  }) async {
    final ext = file.path.split('.').last.toLowerCase(),
        video = [
          'mp4',
          'mov',
        ].contains(file.path.split('.').last.toLowerCase());
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
      throw StateError('Bu dosya türü desteklenmiyor.');
    final size = await file.length();
    if (size == 0 || size > (video ? 100 : 15) * 1024 * 1024)
      throw StateError('Dosya boyutu sınırı aşıldı.');
    final prepared = video
        ? await VideoMediaService.instance.prepare(
            File(file.path),
            maxDuration: null,
          )
        : null;
    final source = prepared?.video ?? File(file.path),
        mime = video ? 'video/mp4' : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
    final doc = plan(id).collection('messages').doc(),
        data = envelope(
          video ? 'Video' : 'Fotoğraf',
          video ? 'video' : 'image',
          reply,
        );
    final bytes = await source.readAsBytes();
    final String encrypted;
    try {
      encrypted = await E2eeService.instance.upload(
        id,
        doc.id,
        bytes,
        contentType: mime,
        scope: 'route',
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
    await _send(id, {
      ...data,
      'storagePath': encrypted,
      'inAlbum': addToAlbum,
    }, messageId: doc.id);
    // An explicit album share is separate from the encrypted chat. Never place
    // the encrypted attachment descriptor (which contains its key) in an album.
    if (addToAlbum) {
      final ref = FirebaseStorage.instance.ref(
        'route_albums/$id/${data['senderId']}/${doc.id}/media.${video
            ? 'mp4'
            : ext == 'jpeg'
            ? 'jpg'
            : ext}',
      );
      await ref.putFile(source, SettableMetadata(contentType: mime));
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('finalizePrivateMedia')
          .call({'storagePath': ref.fullPath});
      await plan(id).collection('album').doc(doc.id).set({
        'ownerId': data['senderId'],
        'ownerName': data['senderName'],
        'storagePath': ref.fullPath,
        'thumbnailPath': '',
        'kind': data['type'],
        'allowExport': allowExport,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
