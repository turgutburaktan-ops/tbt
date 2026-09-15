import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/external_share_service.dart';
import '../services/external_source_url.dart';
import 'create_post_screen.dart';
import 'story_photo_editor_screen.dart';

/// Every external share is a draft. Receiving content never publishes it.
class ImportShareScreen extends StatefulWidget {
  const ImportShareScreen({super.key, this.text = '', this.images = const [], this.videos = const []});
  final String text;
  final List<String> images, videos;
  @override
  State<ImportShareScreen> createState() => _ImportShareScreenState();
}
class _ImportShareScreenState extends State<ImportShareScreen> {
  late final _text = TextEditingController(text: widget.text);
  late final _images = [...widget.images];
  late final _videos = [...widget.videos];
  bool _busy = false;
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  void _error(Object error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
  Future<void> _gallery(bool video) async {
    try {
      if (video) {
        final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (file != null && mounted) setState(() => _videos.add(file.path));
      } else {
        final files = await ImagePicker().pickMultiImage(limit: 10);
        if (mounted) setState(() => _images.addAll(files.map((file) => file.path)));
      }
    } catch (e) { _error(e); }
  }
  Future<void> _open({String? video, List<String> images = const [], bool story = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => story
        ? StoryPhotoEditorScreen(photo: File(video ?? images.first), videoMode: video != null)
        : CreatePostScreen(initialImagePaths: images, initialVideoPath: video, initialCaption: _text.text)));
      if (result == true && mounted) setState(() { if (video != null) _videos.remove(video); for (final image in images) { _images.remove(image); } });
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _publishLink() async {
    final source = externalSourceUrl(_text.text);
    if (source == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ExternalShareService.publishLink(source, _text.text);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı paylaşıldı.'))); Navigator.pop(context); }
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final source = externalSourceUrl(_text.text);
    return PopScope(canPop: !_busy, child: Scaffold(
      appBar: AppBar(title: const Text('TBT’ye aktar')),
      body: AbsorbPointer(absorbing: _busy, child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Paylaşmadan önce düzenle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: _text, minLines: 2, maxLines: 7, maxLength: 500, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Instagram veya X bağlantısını yapıştır; açıklamanı ekle')),
        if (source != null) Card(child: ListTile(leading: const Icon(Icons.link), title: Text(source.host), subtitle: Text(source.toString(), maxLines: 2, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.open_in_new), onTap: () => launchUrl(source, mode: LaunchMode.externalApplication))),
        if (_images.isEmpty && _videos.isEmpty && source != null) ...[
          const Text('Bu paylaşımda yalnızca bağlantı var. Bağlantı kartını paylaşabilir veya kendi fotoğraf/videonu ekleyebilirsin.'),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _publishLink, icon: const Icon(Icons.link), label: const Text('Bağlantı olarak paylaş')),
        ],
        if (!kIsWeb) ...[
          Wrap(spacing: 10, children: [
            OutlinedButton.icon(onPressed: () => _gallery(false), icon: const Icon(Icons.photo_library_outlined), label: const Text('Fotoğraf ekle')),
            OutlinedButton.icon(onPressed: () => _gallery(true), icon: const Icon(Icons.video_library_outlined), label: const Text('Video ekle')),
          ]),
          if (_images.isNotEmpty) ...[
            Text('${_images.length} fotoğraf'),
            SizedBox(height: 110, child: ListView(scrollDirection: Axis.horizontal, children: _images.map((path) => Stack(children: [
              Padding(padding: const EdgeInsets.all(4), child: Image.file(File(path), width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
              IconButton(onPressed: () => setState(() => _images.remove(path)), icon: const Icon(Icons.close)),
            ])).toList())),
            FilledButton(onPressed: () => _open(images: _images.take(10).toList()), child: const Text('Fotoğrafları gönderi olarak düzenle')),
            for (final path in _images) TextButton(onPressed: () => _open(images: [path], story: true), child: Text('${_images.indexOf(path) + 1}. fotoğrafı hikâye yap')),
          ],
          for (final path in _videos) Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.movie_outlined), title: Text('${_videos.indexOf(path) + 1}. video'), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _videos.remove(path)))),
            Wrap(spacing: 8, children: [TextButton(onPressed: () => _open(video: path), child: const Text('Reels olarak düzenle')), TextButton(onPressed: () => _open(video: path, story: true), child: const Text('Hikâye olarak düzenle'))]),
          ])),
        ],
        if (_busy) const LinearProgressIndicator(),
      ])),
    ));
  }
}
