import 'external_source_url.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/import_share_screen.dart';


class ExternalShareService {
  ExternalShareService._();
  static final instance = ExternalShareService._();
  StreamSubscription<List<SharedMediaFile>>? _media;
  StreamSubscription<User?>? _auth;
  GlobalKey<NavigatorState>? _key;
  Future<void> _receiving = Future.value();
  bool _open = false;
  String? _recent;
  final _queue = <Map<String, dynamic>>[];
  static const _pendingKey = 'external_share_pending_v1';

  Future<void> start(GlobalKey<NavigatorState> key) async {
    if (kIsWeb || _key != null) return;
    _key = key;
    final prefs = await SharedPreferences.getInstance();
    try {
      final saved = jsonDecode(prefs.getString(_pendingKey) ?? '[]') as List;
      _queue.addAll(saved.map((item) => Map<String, dynamic>.from(item as Map)));
    } catch (_) { await prefs.remove(_pendingKey); }
    _auth = FirebaseAuth.instance.authStateChanges().listen((_) => _drain());
    _media = ReceiveSharingIntent.instance.getMediaStream().listen(_enqueue,
      onError: (Object _) => _notice('Paylaşılan içerik alınamadı. TBT’ye aktar ekranından tekrar deneyebilirsin.'));
    try { _enqueue(await ReceiveSharingIntent.instance.getInitialMedia()); }
    catch (_) { _notice('Paylaşılan içerik alınamadı.'); }
    _drain();
  }
  void _notice(String message) {
    final context = _key?.currentContext;
    if (context != null) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }
  void _enqueue(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final signature = jsonEncode(files.map((item) => item.toMap()).toList());
    if (_recent == signature) return;
    _recent = signature;
    Timer(const Duration(seconds: 3), () { if (_recent == signature) _recent = null; });
    _receiving = _receiving.then((_) async {
      try {
        if (files.length > 20) throw Exception('Tek seferde en fazla 20 dosya aktarabilirsin.');
        final root = await getApplicationSupportDirectory();
        final folder = await Directory('${root.path}/incoming_shares/${DateTime.now().microsecondsSinceEpoch}').create(recursive: true);
        final images = <String>[], videos = <String>[], texts = <String>[];
        for (var i = 0; i < files.length; i++) {
          final item = files[i];
          if (item.message?.trim().isNotEmpty == true && !texts.contains(item.message)) texts.add(item.message!);
          if (item.type == SharedMediaType.text || item.type == SharedMediaType.url) { texts.add(item.path); continue; }
          if (item.type != SharedMediaType.image && item.type != SharedMediaType.video) continue;
          final file = File(item.path);
          final size = await file.length();
          if (size <= 0 || size > (item.type == SharedMediaType.video ? 250 : 40) * 1024 * 1024) throw Exception('Dosya boyutu desteklenmiyor.');
          final suffix = RegExp(r'\.[a-zA-Z0-9]{1,5}$').firstMatch(file.path)?.group(0) ?? (item.type == SharedMediaType.video ? '.mp4' : '.jpg');
          final copy = await file.copy('${folder.path}/$i$suffix');
          (item.type == SharedMediaType.video ? videos : images).add(copy.path);
        }
        if (texts.isEmpty && images.isEmpty && videos.isEmpty) throw Exception('Bu içerik türü desteklenmiyor.');
        _queue.add({'text': texts.join('\n'), 'images': images, 'videos': videos});
        await _persist();
        await ReceiveSharingIntent.instance.reset();
        _drain();
      } catch (e) { _notice('İçerik aktarılamadı: $e'); }
    });
  }
  Future<void> _persist() async => (await SharedPreferences.getInstance()).setString(_pendingKey, jsonEncode(_queue));
  void _drain() {
    if (_open || _queue.isEmpty || FirebaseAuth.instance.currentUser == null || _key == null) return;
    _open = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final nav = _key?.currentState;
      if (nav == null) { _open = false; return; }
      final draft = _queue.first;
      try {
        await nav.push(MaterialPageRoute(builder: (_) => ImportShareScreen(text: draft['text'] as String? ?? '', images: List<String>.from(draft['images'] as List? ?? []), videos: List<String>.from(draft['videos'] as List? ?? []))));
        _queue.remove(draft);
        await _persist();
      } finally { _open = false; _drain(); }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
  void dispose() { _media?.cancel(); _auth?.cancel(); _key = null; }

  /// Render a local source card so existing profiles and older clients have a
  /// valid thumbnail. We never fetch arbitrary URLs or scrape external media.
  static Future<void> publishLink(Uri source, String caption) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Paylaşmak için giriş yapmalısın.');
    if (externalSourceUrl(source.toString()) == null || caption.length > 500) throw Exception('Geçerli bağlantı ve en fazla 500 karakter açıklama gerekli.');
    final db = FirebaseFirestore.instance;
    final existing = await db.collection('posts').where('userId', isEqualTo: user.uid).where('externalSourceUrl', isEqualTo: source.toString()).limit(1).get();
    if (existing.docs.isNotEmpty) throw Exception('Bu bağlantıyı daha önce paylaşmışsın.');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 720), Paint()..color = const Color(0xFF11191D));
    void line(String text, double top, double size, Color color) {
      final painter = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr, maxLines: 4, ellipsis: '…')..layout(maxWidth: 936);
      painter.paint(canvas, Offset(72, top));
    }
    line('TBT · BAĞLANTI', 65, 28, const Color(0xFF55D6D0));
    line(source.host.contains('instagram') ? 'Instagram paylaşımı' : 'X paylaşımı', 160, 54, Colors.white);
    line(caption.replaceAll(source.toString(), '').trim().isEmpty ? source.path : caption, 260, 32, Colors.white70);
    line(source.host, 620, 26, Colors.white54);
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(1080, 720);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose(); picture.dispose();
    if (bytes == null) throw Exception('Bağlantı kartı oluşturulamadı.');
    final post = db.collection('posts').doc();
    final storage = FirebaseStorage.instance.ref('users/${user.uid}/posts/${post.id}.png');
    try {
      await storage.putData(bytes.buffer.asUint8List(), SettableMetadata(contentType: 'image/png'));
      await post.set({'id': post.id, 'userId': user.uid, 'userName': user.displayName ?? 'TBT kullanıcısı', 'userPhotoUrl': user.photoURL ?? '', 'caption': caption.trim(), 'spotName': '', 'mediaType': 'image', 'imageUrl': await storage.getDownloadURL(), 'storagePath': storage.fullPath, 'sourceType': 'post', 'externalSourceUrl': source.toString(), 'isExternalLink': true, 'likesCount': 0, 'commentsCount': 0, 'durationMs': 0, 'businessOfficial': false, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) { try { await storage.delete(); } catch (_) {} rethrow; }
  }
}
