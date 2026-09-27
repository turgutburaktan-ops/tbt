import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

// Legacy token URLs are parsed only to identify an object, never fetched as URLs.
bool isPrivateChatPath(String path) =>
    RegExp(r'^users/[^/]+/chat/[^/]+/[^/]+$').hasMatch(path) ||
    RegExp(r'^private_chat/[^/]+/[^/]+/[^/]+/(media\.(jpg|png|webp)|audio\.m4a)$').hasMatch(path);

class PrivateChatMedia {
  static Future<Directory>? _audioRoot;
  static Future<Directory> _prepareAudioRoot() async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/tbt_private_chat');
    // Remove leftovers from a terminated previous process once, before playback.
    if (await directory.exists()) await directory.delete(recursive: true);
    return directory.create(recursive: true);
  }
  static Reference reference(String value) {
    final storage=FirebaseStorage.instance;
    final ref=storage.refFromURL(value);
    if (ref.bucket != storage.ref().bucket || !isPrivateChatPath(ref.fullPath)) {
      throw Exception('Geçersiz mesaj medyası.');
    }
    return ref;
  }
  static Future<Uint8List> read(String value, {int maxBytes=15*1024*1024}) async {
    final uid=FirebaseAuth.instance.currentUser?.uid;
    if (uid==null) throw Exception('Giriş yapmalısın.');
    final data=await reference(value).getData(maxBytes).timeout(const Duration(seconds:30));
    if (FirebaseAuth.instance.currentUser?.uid != uid || data==null) {
      data?.fillRange(0,data.length,0);
      throw Exception('Medya erişimi sona erdi.');
    }
    return data;
  }
  static Future<Directory> audioFile(String value) async {
    final uid=FirebaseAuth.instance.currentUser?.uid;
    final bytes=await read(value,maxBytes:20*1024*1024);
    final directory=await (_audioRoot ??= _prepareAudioRoot());
    final session=await directory.createTemp('audio_');
    try {
      await File('${session.path}/audio.m4a').writeAsBytes(bytes,flush:true);
      if (FirebaseAuth.instance.currentUser?.uid != uid) throw Exception('Oturum değişti.');
      return session;
    } catch (_) {
      await session.delete(recursive:true);
      rethrow;
    } finally {
      bytes.fillRange(0,bytes.length,0);
    }
  }
}
