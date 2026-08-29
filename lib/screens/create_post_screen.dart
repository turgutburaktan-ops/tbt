import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../services/content_engagement_service.dart';
import '../services/multi_photo_post_service.dart';
import '../services/post_service.dart';
import '../widgets/app_video_player.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialImagePath;
  final String businessVenueKey;
  final String businessVenueName;

  const CreatePostScreen({
    super.key,
    this.initialImagePath,
    this.businessVenueKey = '',
    this.businessVenueName = '',
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _spotController = TextEditingController();
  final List<Map<String, String>> _taggedUsers = <Map<String, String>>[];
  final PageController _pageController = PageController();

  final List<File> _images = <File>[];
  File? _video;
  int _page = 0;
  double? _latitude;
  double? _longitude;
  bool _loading = false;
  bool _gettingLocation = false;

  bool get _hasMedia => _images.isNotEmpty || _video != null;
  bool get _isVideo => _video != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) _images.add(File(widget.initialImagePath!));
    _captionController.addListener(_refreshCaptionCounter);
    if (widget.businessVenueName.isNotEmpty) _spotController.text = widget.businessVenueName;
  }

  void _refreshCaptionCounter() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _captionController
      ..removeListener(_refreshCaptionCounter)
      ..dispose();
    _spotController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _chooseSource() async {
    if (_loading) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF121416),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Fotoğraf veya video ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Fotoğraf çek'), onTap: () => Navigator.pop(sheetContext, 'photo_camera')),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galeriden fotoğraf seç'), subtitle: const Text('Tek gönderide en fazla 10 fotoğraf'), onTap: () => Navigator.pop(sheetContext, 'photo_gallery')),
            const Divider(),
            ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('30 sn video çek'), onTap: () => Navigator.pop(sheetContext, 'video_camera')),
            ListTile(leading: const Icon(Icons.video_library_outlined), title: const Text('Galeriden video seç'), onTap: () => Navigator.pop(sheetContext, 'video_gallery')),
          ]),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.startsWith('video')) {
      await _pickVideo(choice == 'video_camera' ? ImageSource.camera : ImageSource.gallery);
    } else if (choice == 'photo_gallery') {
      await _pickMultipleImages();
    } else {
      await _pickCameraImage();
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final selected = await _picker.pickMultiImage(imageQuality: 92, limit: 10);
      if (selected.isEmpty || !mounted) return;
      setState(() {
        _images
          ..clear()
          ..addAll(selected.take(10).map((x) => File(x.path)));
        _video = null;
        _page = 0;
      });
    } catch (e) {
      if (mounted) _message('Fotoğraflar seçilemedi: $e');
    }
  }

  Future<void> _pickCameraImage() async {
    try {
      final selected = await _picker.pickImage(source: ImageSource.camera);
      if (selected == null || !mounted) return;
      setState(() {
        _images
          ..clear()
          ..add(File(selected.path));
        _video = null;
        _page = 0;
      });
    } catch (e) {
      if (mounted) _message('Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _addMorePhotos() async {
    if (_images.length >= 10) return;
    try {
      final selected = await _picker.pickMultiImage(imageQuality: 92, limit: 10 - _images.length);
      if (selected.isEmpty || !mounted) return;
      setState(() => _images.addAll(selected.take(10 - _images.length).map((x) => File(x.path))));
    } catch (e) {
      if (mounted) _message('Fotoğraflar eklenemedi: $e');
    }
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _images.length) return;
    setState(() {
      _images.removeAt(index);
      _page = _images.isEmpty ? 0 : _page.clamp(0, _images.length - 1);
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final selected = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 30));
      if (selected == null || !mounted) return;
      setState(() {
        _video = File(selected.path);
        _images.clear();
      });
    } catch (e) {
      if (mounted) _message('Video seçilemedi: $e');
    }
  }

  Future<void> _getLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Telefonun konum servisini aç.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('Konum izni verilmedi.');
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _message('Konum eklendi.');
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _addTag() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0E1012),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .64,
        child: Column(children: [ const Padding(padding: EdgeInsets.all(18), child: Text('Açıklamaya kişi etiketle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), const Divider(color: Colors.white12), Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ContentEngagementService.instance.users(),
          builder: (_, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final users = snapshot.data!.docs.where((d) => d.id != me).toList();
            return ListView.builder(itemCount: users.length, itemBuilder: (_, index) {
              final doc = users[index];
              final data = doc.data();
              final name = (data['displayName'] ?? data['email'] ?? 'Kullanıcı').toString().trim();
              final username = (data['username'] ?? data['usernameNormalized'] ?? '').toString().trim();
              final mention = username.isNotEmpty ? username : name.replaceAll(' ', '');
              return ListTile(title: Text(name), subtitle: username.isEmpty ? null : Text('@$username'), onTap: () => Navigator.pop(sheetContext, {'id': doc.id, 'name': name, 'mention': mention}));
            });
          },
        ))]),
      ),
    );
    if (selected == null || !mounted) return;
    final id = selected['id'] ?? '';
    if (id.isEmpty || _taggedUsers.any((u) => u['id'] == id)) return;
    setState(() {
      _taggedUsers.add(selected);
      final mention = '@${selected['mention'] ?? selected['name'] ?? 'kullanici'}';
      final current = _captionController.text.trimRight();
      _captionController.text = current.isEmpty ? mention : '$current $mention';
      _captionController.selection = TextSelection.collapsed(offset: _captionController.text.length);
    });
  }

  void _removeTag(Map<String, String> user) {
    setState(() {
      _taggedUsers.removeWhere((u) => u['id'] == user['id']);
      final mention = user['mention'] ?? user['name'] ?? '';
      if (mention.isNotEmpty) _captionController.text = _captionController.text.replaceAll('@$mention', '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    });
  }

  Future<void> _share() async {
    if (!_hasMedia) return _message('Önce bir fotoğraf veya video seç.');
    if (_spotController.text.trim().isEmpty) return _message('Çekim noktası adını yaz.');
    if (PostService.instance.currentUser == null) return _message('Paylaşım yapmak için giriş yapmalısın.');
    setState(() => _loading = true);
    try {
      final ids = _taggedUsers.map((u) => u['id'] ?? '').where((e) => e.isNotEmpty).toList();
      final names = _taggedUsers.map((u) => u['name'] ?? '').where((e) => e.isNotEmpty).toList();
      if (_isVideo) {
        await PostService.instance.createVideoPost(video: _video!, caption: _captionController.text, spotName: _spotController.text, latitude: _latitude, longitude: _longitude, taggedUserIds: ids, taggedUserNames: names, businessVenueKey: widget.businessVenueKey, businessVenueName: widget.businessVenueName);
      } else {
        await MultiPhotoPostService.instance.createPost(images: _images, caption: _captionController.text, spotName: _spotController.text, latitude: _latitude, longitude: _longitude, taggedUserIds: ids, taggedUserNames: names, businessVenueKey: widget.businessVenueKey, businessVenueName: widget.businessVenueName);
      }
      if (!mounted) return;
      _message(_isVideo ? 'Video başarıyla paylaşıldı! 🎬' : '${_images.length} fotoğraf başarıyla paylaşıldı! 📸');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _message('Paylaşım başarısız: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _mediaPreview() {
    if (_video != null) return AppVideoPlayer.file(file: _video!, autoplay: true, muted: true, loop: true, fit: BoxFit.cover);
    if (_images.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_to_photos_outlined, color: Color(0xFFB7BCC2), size: 68), SizedBox(height: 14), Text('Fotoğraf veya video ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('Tek gönderide 10 fotoğrafa kadar', style: TextStyle(color: Colors.white54))]));
    return Stack(children: [
      PageView.builder(controller: _pageController, itemCount: _images.length, onPageChanged: (i) => setState(() => _page = i), itemBuilder: (_, i) => Image.file(_images[i], width: double.infinity, height: double.infinity, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.low)),
      if (_images.length > 1) Positioned(top: 12, right: 12, child: DecoratedBox(decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('${_page + 1}/${_images.length}', style: const TextStyle(fontWeight: FontWeight.w800))))),
      Positioned(top: 8, left: 8, child: IconButton.filledTonal(onPressed: () => _removePhoto(_page), icon: const Icon(Icons.delete_outline))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB7BCC2);
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0C), foregroundColor: Colors.white, title: Text(widget.businessVenueName.isEmpty ? 'Paylaş' : '${widget.businessVenueName} • Paylaş')),
      body: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.fromLTRB(18, 16, 18, 40), children: [
        GestureDetector(onTap: _chooseSource, child: Container(height: 300, decoration: BoxDecoration(color: const Color(0xFF121416), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x334B5158))), clipBehavior: Clip.antiAlias, child: _mediaPreview())),
        if (_images.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [Text('${_images.length}/10 fotoğraf', style: const TextStyle(color: Colors.white60)), const Spacer(), if (_images.length < 10) TextButton.icon(onPressed: _loading ? null : _addMorePhotos, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Fotoğraf ekle')), TextButton.icon(onPressed: _loading ? null : _chooseSource, icon: const Icon(Icons.edit), label: const Text('Değiştir'))])),
        if (_isVideo) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _loading ? null : _chooseSource, icon: const Icon(Icons.edit), label: const Text('Videoyu değiştir'))),
        const SizedBox(height: 16),
        TextField(controller: _spotController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Çekim noktası adı', hintText: 'Örn. Harput Kalesi', prefixIcon: const Icon(Icons.place_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _gettingLocation ? null : _getLocation, icon: _gettingLocation ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location), label: Text(_latitude == null ? 'Konum ekle' : 'Konum eklendi')),
        const SizedBox(height: 16),
        TextField(controller: _captionController, minLines: 3, maxLines: 7, maxLength: 1000, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Açıklama', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)))),
        Row(children: [TextButton.icon(onPressed: _addTag, icon: const Icon(Icons.alternate_email), label: const Text('Kişi etiketle')), const Spacer(), Text('${_captionController.text.length}/1000', style: const TextStyle(color: Colors.white38, fontSize: 12))]),
        if (_taggedUsers.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: _taggedUsers.map((u) => InputChip(label: Text(u['name'] ?? 'Kullanıcı'), onDeleted: () => _removeTag(u))).toList()),
        const SizedBox(height: 22),
        SizedBox(height: 54, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: _loading ? null : _share, child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_images.length > 1 ? '${_images.length} fotoğrafı paylaş' : 'Paylaş', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))),
      ]),
    );
  }
}
