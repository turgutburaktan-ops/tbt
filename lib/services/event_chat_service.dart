import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EventChatService {
  static final instance = EventChatService();
  CollectionReference<Map<String, dynamic>> messages(String id) => FirebaseFirestore.instance.collection('social_events').doc(id).collection('chat');
  Map<String, dynamic> _data(String text, String type, Map<String, dynamic>? reply) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    final name = user.displayName?.trim();
    return {'senderId': user.uid, 'senderName': (name == null || name.isEmpty ? 'Katılımcı' : name).substring(0, (name == null || name.isEmpty ? 'Katılımcı' : name).length.clamp(0, 100)), 'text': text, 'type': type, if (reply != null) 'reply': reply, 'createdAt': FieldValue.serverTimestamp()};
  }
  Future<void> send(String id, String text, {Map<String, dynamic>? reply}) async {
    if (text.trim().isEmpty || text.trim().length > 1500) throw Exception('Mesaj 1–1500 karakter olmalı.');
    await messages(id).add(_data(text.trim(), 'text', reply));
  }
  Future<void> location(String id, String label, double lat, double lng, {Map<String, dynamic>? reply}) async {
    await messages(id).add({..._data(label.isEmpty ? 'Paylaşılan konum' : label, 'location', reply), 'latitude': lat, 'longitude': lng});
  }
  Future<void> audio(String id, Uint8List bytes, int duration, {Map<String, dynamic>? reply}) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) throw Exception('Ses kaydı en fazla 20 MB olabilir.');
    final data = _data('Sesli mesaj', 'audio', reply), doc = messages(id).doc();
    final ref = FirebaseStorage.instance.ref('event_chat/$id/${data['senderId']}/${doc.id}/audio.m4a');
    await ref.putData(bytes, SettableMetadata(contentType: 'audio/mp4'));
    await doc.set({...data, 'storagePath': ref.fullPath, 'durationMs': duration});
  }
  Future<void> media(String id, XFile file, {Map<String, dynamic>? reply}) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg','jpeg','png','webp','heic','heif','mp4','mov'].contains(ext)) throw Exception('Bu dosya türü desteklenmiyor.');
    final video = ['mp4','mov'].contains(ext), size = await file.length();
    if (size == 0 || size > (video ? 100 : 15) * 1024 * 1024) throw Exception(video ? 'Video en fazla 100 MB olabilir.' : 'Fotoğraf en fazla 15 MB olabilir.');
    final data = _data(video ? 'Video' : 'Fotoğraf', video ? 'video' : 'image', reply), doc = messages(id).doc();
    final extension = ext == 'jpeg' ? 'jpg' : ext;
    final mime = video ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4') : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
    final ref = FirebaseStorage.instance.ref('event_chat/$id/${data['senderId']}/${doc.id}/media.$extension');
    await ref.putFile(File(file.path), SettableMetadata(contentType: mime));
    await doc.set({...data, 'storagePath': ref.fullPath});
  }
}
