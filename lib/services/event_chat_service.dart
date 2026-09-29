import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'e2ee_service.dart';
import 'video_media_service.dart';

class EventChatService {
  static final instance = EventChatService();
  CollectionReference<Map<String, dynamic>> messages(String id) =>
      FirebaseFirestore.instance
          .collection('social_events')
          .doc(id)
          .collection('chat');
  Map<String, dynamic> _data(
    String text,
    String type,
    Map<String, dynamic>? reply,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Giriş yapmalısın.');
    return {
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Katılımcı',
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
    messageId ?? messages(id).doc().id,
    content,
    scope: 'event',
  );
  Future<void> send(
    String id,
    String text, {
    Map<String, dynamic>? reply,
  }) async {
    if (text.trim().isEmpty || text.trim().length > 1500)
      throw StateError('Mesaj 1–1500 karakter olmalı.');
    await _send(id, _data(text.trim(), 'text', reply));
  }

  Future<void> location(
    String id,
    String label,
    double lat,
    double lng, {
    Map<String, dynamic>? reply,
  }) => _send(id, {
    ..._data(label.isEmpty ? 'Paylaşılan konum' : label, 'location', reply),
    'latitude': lat,
    'longitude': lng,
  });
  Future<void> audio(
    String id,
    Uint8List bytes,
    int duration, {
    Map<String, dynamic>? reply,
  }) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024)
      throw StateError('Ses kaydı en fazla 20 MB olabilir.');
    final message = messages(id).doc().id;
    final path = await E2eeService.instance.upload(
      id,
      message,
      bytes,
      contentType: 'audio/mp4',
      scope: 'event',
    );
    await _send(id, {
      ..._data('Sesli mesaj', 'audio', reply),
      'storagePath': path,
      'durationMs': duration,
    }, messageId: message);
  }

  Future<void> media(
    String id,
    XFile file, {
    Map<String, dynamic>? reply,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
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
    final video = ['mp4', 'mov'].contains(ext), size = await file.length();
    if (size == 0 || size > (video ? 100 : 15) * 1024 * 1024)
      throw StateError('Dosya boyutu sınırı aşıldı.');
    final prepared = video
        ? await VideoMediaService.instance.prepare(
            File(file.path),
            maxDuration: null,
          )
        : null;
    final message = messages(id).doc().id,
        bytes = await (prepared?.video ?? File(file.path)).readAsBytes();
    final String path;
    try {
      path = await E2eeService.instance.upload(
        id,
        message,
        bytes,
        contentType: video
            ? 'video/mp4'
            : 'image/${ext == 'jpg' ? 'jpeg' : ext}',
        scope: 'event',
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
    await _send(id, {
      ..._data(video ? 'Video' : 'Fotoğraf', video ? 'video' : 'image', reply),
      'storagePath': path,
    }, messageId: message);
  }
}
