import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/safe_image_service.dart';
import '../services/video_media_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_video_player.dart';

import '../models/travel_plan.dart';
import '../services/user_facing_error.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';
import 'story_photo_editor_screen.dart';
import 'story_video_editor_screen.dart';

class RouteAlbumScreen extends StatefulWidget {
  const RouteAlbumScreen({super.key, required this.plan});
  final TravelPlan plan;
  @override
  State<RouteAlbumScreen> createState() => _RouteAlbumScreenState();
}

class _RouteAlbumScreenState extends State<RouteAlbumScreen> {
  bool _uploading = false;
  String _progress = '';
  late final _album = FirebaseFirestore.instance
      .collection('travel_plans')
      .doc(widget.plan.id)
      .collection('album');
  late final _stream = _album
      .orderBy('createdAt', descending: true)
      .snapshots();
  Future<void> _upload() async {
    if (_uploading) return;
    var stage = 'Fotoğraf ve video seçimi';
    try {
      final picked = await ImagePicker().pickMultipleMedia();
      if (picked.isEmpty || !mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Giriş yapmalısın.');
      final key = 'route_album_export_$uid';
      bool? allowed = prefs.getBool(key);
      if (allowed == null) {
        allowed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Albüm paylaşımı'),
            content: const Text(
              'Katılımcılar yüklediğin fotoğraf ve videoları indirip story, gönderi veya Reels olarak paylaşabilsin mi? Bu tercihi yüklediğin içerikten değiştirebilirsin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Yalnızca görüntülesin'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('İzin ver'),
              ),
            ],
          ),
        );
        if (allowed == null || !mounted) return;
        await prefs.setBool(key, allowed);
      }
      if (!mounted) return;
      setState(() => _uploading = true);
      for (var i = 0; i < picked.length; i++) {
        if (!mounted) break;
        setState(() => _progress = '${i + 1}/${picked.length} yükleniyor');
        final file = picked[i];
        final ext = file.path.split('.').last.toLowerCase();
        final video =
            ['mp4', 'mov', 'm4v'].contains(ext) ||
            file.mimeType?.startsWith('video/') == true;
        final size = await file.length();
        if (size > (video ? 100 : 15) * 1024 * 1024)
          throw Exception(
            video
                ? 'Video 100 MB sınırını aşıyor.'
                : 'Fotoğraf 15 MB sınırını aşıyor.',
          );
        final doc = _album.doc();
        final extension = video
            ? 'mp4'
            : ['png', 'webp', 'heic', 'heif'].contains(ext)
            ? ext
            : 'jpg';
        final mime = video
            ? (extension == 'mov' ? 'video/quicktime' : 'video/mp4')
            : 'image/${extension == 'jpg' ? 'jpeg' : extension}';
        final base = 'route_albums/${widget.plan.id}/$uid/${doc.id}';
        final ref = FirebaseStorage.instance.ref('$base/media.$extension');
        final thumb = FirebaseStorage.instance.ref('$base/thumb.jpg');
        stage = 'Video hazırlanıyor';
        final prepared = video
            ? await VideoMediaService.instance.prepare(File(file.path), maxDuration: null)
            : null;
        bool mediaDone = false, thumbDone = false;
        try {
          stage = 'Albüm dosyasının yüklenmesi';
          await ref.putFile(
            prepared?.video ?? File(file.path),
            SettableMetadata(contentType: mime),
          );
          mediaDone = true;
          Uint8List? thumbnail;
          if (prepared != null) {
            thumbnail = await prepared.thumbnail.readAsBytes();
          } else {
            thumbnail = await SafeImageService.thumbnail(file.path);
          }
          if (thumbnail != null) {
            stage = 'Albüm önizlemesinin yüklenmesi';
            await thumb.putData(
              thumbnail,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            thumbDone = true;
          }
          stage = 'İçeriğin albüme eklenmesi';
          await doc.set({
            'ownerId': uid,
            'ownerName':
                FirebaseAuth.instance.currentUser?.displayName ?? 'Katılımcı',
            'storagePath': ref.fullPath,
            'thumbnailPath': thumbDone ? thumb.fullPath : '',
            'kind': video ? 'video' : 'image',
            'allowExport': allowed,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          if (mediaDone)
            try {
              await ref.delete();
            } catch (_) {}
          if (thumbDone)
            try {
              await thumb.delete();
            } catch (_) {}
          rethrow;
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$stage tamamlanamadı. ${userFacingError(e)}'),
          ),
        );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Yalnızca katılımcılar görebilir',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            FilledButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Fotoğraf / video ekle'),
            ),
          ],
        ),
      ),
      if (_uploading) ...[
        const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.all(8), child: Text(_progress)),
      ],
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (_, s) {
            if (s.hasError)
              return Center(child: Text(userFacingError(s.error!)));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            if (s.data!.docs.isEmpty)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Gezinin ilk anısını ekle. Fotoğraf ve videolarınız burada birikecek.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            return GridView.builder(
              padding: const EdgeInsets.all(3),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: s.data!.docs.length,
              itemBuilder: (_, i) {
                final doc = s.data!.docs[i], d = doc.data();
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AlbumViewer(reference: doc.reference),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _PrivateThumbnail(
                        path: (d['thumbnailPath'] ?? '').toString(),
                      ),
                      if (d['kind'] == 'video')
                        const Positioned(
                          top: 5,
                          right: 5,
                          child: Icon(Icons.play_circle_fill),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            '${d['ownerName']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _PrivateThumbnail extends StatefulWidget {
  const _PrivateThumbnail({required this.path});
  final String path;
  @override
  State<_PrivateThumbnail> createState() => _PrivateThumbnailState();
}

class _PrivateThumbnailState extends State<_PrivateThumbnail> {
  late final Future<Uint8List?> _bytes = widget.path.isEmpty
      ? Future.value(null)
      : FirebaseStorage.instance.ref(widget.path).getData(3 * 1024 * 1024);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (_, s) => s.data != null
        ? Image.memory(s.data!, fit: BoxFit.cover)
        : const ColoredBox(
            color: AppColors.surfaceAlt,
            child: Center(
              child: Icon(Icons.photo_library_outlined, color: Colors.white38),
            ),
          ),
  );
}

class _AlbumViewer extends StatefulWidget {
  const _AlbumViewer({required this.reference});
  final DocumentReference<Map<String, dynamic>> reference;
  @override
  State<_AlbumViewer> createState() => _AlbumViewerState();
}

class _AlbumViewerState extends State<_AlbumViewer> {
  File? _file;
  bool _isVideo = false;
  String? _error;
  bool _busy = false;
  late final _stream = widget.reference.snapshots();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = (await widget.reference.get()).data();
      if (d == null) throw Exception('Bu içerik kaldırılmış.');
      final path = d['storagePath'] as String;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/tbt_album_${widget.reference.id}.${path.split('.').last}',
      );
      await FirebaseStorage.instance.ref(path).writeToFile(file);
      if (!mounted) {
        await file.delete();
        return;
      }
      _file = file;
      _isVideo = d['kind'] == 'video';
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    }
  }

  @override
  void dispose() {
    final f = _file;
    if (f != null) f.delete().catchError((_) => f);
    super.dispose();
  }

  Future<void> _action(String action) async {
    if (_busy || _file == null) return;
    setState(() => _busy = true);
    try {
      final d = (await widget.reference.get()).data();
      if (d == null) throw Exception('Bu içerik kaldırılmış.');
      if (!mounted) return;
      final owned = d['ownerId'] == FirebaseAuth.instance.currentUser?.uid;
      if (action == 'delete' && owned) {
        final yes = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Albümden kaldır?'),
            content: const Text('Bu içerik ortak albümden kaldırılacak.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Kaldır'),
              ),
            ],
          ),
        );
        if (yes != true) return;
        await FirebaseStorage.instance.ref(d['storagePath'] as String).delete();
        final thumb = (d['thumbnailPath'] ?? '').toString();
        if (thumb.isNotEmpty)
          await FirebaseStorage.instance.ref(thumb).delete();
        await widget.reference.delete();
        if (mounted) Navigator.pop(context);
        return;
      }
      if (action == 'permission') {
        await widget.reference.update({
          'allowExport': d['allowExport'] != true,
        });
        return;
      }
      if (!owned && d['allowExport'] != true)
        throw Exception('İçeriği yükleyen kişi paylaşmaya izin vermemiş.');
      if (action == 'download') {
        await const MethodChannel('tbt/album_export').invokeMethod(
          'saveMedia',
          {'path': _file!.path, 'video': d['kind'] == 'video'},
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Galeriye kaydedildi.')));
      } else if (mounted) {
        final isVideo = d['kind'] == 'video';
        final Widget screen = action == 'story'
            ? (isVideo
                  ? StoryVideoEditorScreen(video: _file!)
                  : StoryPhotoEditorScreen(photo: _file!))
            : CreatePostScreen(
                initialImagePath: isVideo ? null : _file!.path,
                initialVideoPath: isVideo ? _file!.path : null,
              );
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (_, s) {
          final d = s.data?.data();
          final denied = s.hasError || (s.hasData && d == null);
          final owned = d?['ownerId'] == FirebaseAuth.instance.currentUser?.uid;
          final allowed = owned || d?['allowExport'] == true;
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(d?['ownerName']?.toString() ?? 'Albüm'),
              actions: [
                if (owned)
                  IconButton(
                    tooltip: 'İndirme ve paylaşma izni',
                    onPressed: _busy ? null : () => _action('permission'),
                    icon: Icon(
                      d?['allowExport'] == true
                          ? Icons.lock_open
                          : Icons.lock_outline,
                    ),
                  ),
              ],
            ),
            body: denied
                ? const Center(child: Text('Bu içeriğe artık erişilemiyor.'))
                : _error != null
                ? Center(child: Text(_error!))
                : _file == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: _isVideo
                        ? AppVideoPlayer.file(file: _file!, autoplay: false, active: !_busy, muted: false, showMuteControl: false)
                        : InteractiveViewer(child: Image.file(_file!)),
                  ),
            bottomNavigationBar: denied
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: allowed
                          ? Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              children: [
                                for (final a in [
                                  ('download', 'İndir', Icons.download),
                                  ('story', 'Story', Icons.add_circle_outline),
                                  (
                                    'post',
                                    d?['kind'] == 'video' ? 'Reels' : 'Gönderi',
                                    Icons.send_outlined,
                                  ),
                                ])
                                  OutlinedButton.icon(
                                    onPressed: _busy || _file == null
                                        ? null
                                        : () => _action(a.$1),
                                    icon: Icon(a.$3, size: 18),
                                    label: Text(a.$2),
                                  ),
                              ],
                            )
                          : const Text(
                              'Yükleyen kişi indirme ve paylaşmayı kapattı.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60),
                            ),
                    ),
                  ),
          );
        },
      );
}
