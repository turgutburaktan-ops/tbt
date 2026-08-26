import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../services/content_engagement_service.dart';
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

  File? _image;
  File? _video;
  double? _latitude;
  double? _longitude;
  bool _loading = false;
  bool _gettingLocation = false;

  bool get _hasMedia => _image != null || _video != null;
  bool get _isVideo => _video != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _image = File(widget.initialImagePath!);
    }
    _captionController.addListener(_refreshCaptionCounter);
    if (widget.businessVenueName.isNotEmpty) {
      _spotController.text = widget.businessVenueName;
    }
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
    super.dispose();
  }

  Future<void> _chooseSource() async {
    if (_loading) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF121416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fotoğraf veya video ekle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Fotoğraf çek'),
                onTap: () => Navigator.pop(sheetContext, 'photo_camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden fotoğraf seç'),
                onTap: () => Navigator.pop(sheetContext, 'photo_gallery'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('30 sn video çek'),
                subtitle: const Text('Paylaşım videosu en fazla 30 saniye'),
                onTap: () => Navigator.pop(sheetContext, 'video_camera'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Galeriden video seç'),
                subtitle: const Text('30 saniyeye kadar'),
                onTap: () => Navigator.pop(sheetContext, 'video_gallery'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.startsWith('video')) {
      await _pickVideo(
        choice == 'video_camera' ? ImageSource.camera : ImageSource.gallery,
      );
    } else {
      await _pickImage(
        choice == 'photo_camera' ? ImageSource.camera : ImageSource.gallery,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final selected = await _picker.pickImage(source: source);
      if (selected == null || !mounted) return;
      setState(() {
        _image = File(selected.path);
        _video = null;
      });
    } catch (e) {
      if (mounted) _message('Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final selected = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _video = File(selected.path);
        _image = null;
      });
    } catch (e) {
      if (mounted) _message('Video seçilemedi: $e');
    }
  }

  Future<void> _getLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Telefonun konum servisini aç.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni verilmedi.');
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _message('Konum eklendi.');
    } catch (e) {
      if (mounted) {
        _message(e.toString().replaceFirst('Exception: ', ''));
      }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .64,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Açıklamaya kişi etiketle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ContentEngagementService.instance.users(),
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Kullanıcılar yüklenemedi.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data!.docs
                      .where((d) => d.id != me)
                      .toList();
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final doc = users[index];
                      final data = doc.data();
                      final displayName =
                          (data['displayName'] ?? data['email'] ?? 'Kullanıcı')
                              .toString()
                              .trim();
                      final username =
                          (data['username'] ?? data['usernameNormalized'] ?? '')
                              .toString()
                              .trim();
                      final mentionName = username.isNotEmpty
                          ? username
                          : displayName.replaceAll(' ', '');
                      final photo = (data['photoUrl'] ?? '').toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1A1D20),
                          backgroundImage: photo.isEmpty
                              ? null
                              : NetworkImage(photo),
                          child: photo.isEmpty
                              ? const Icon(Icons.person_outline)
                              : null,
                        ),
                        title: Text(displayName),
                        subtitle: username.isEmpty ? null : Text('@$username'),
                        onTap: () => Navigator.pop(sheetContext, {
                          'id': doc.id,
                          'name': displayName,
                          'mention': mentionName,
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final id = selected['id'] ?? '';
    if (id.isEmpty || _taggedUsers.any((u) => u['id'] == id)) return;
    setState(() {
      _taggedUsers.add(selected);
      final mention =
          '@${selected['mention'] ?? selected['name'] ?? 'kullanici'}';
      final current = _captionController.text.trimRight();
      _captionController.text = current.isEmpty ? mention : '$current $mention';
      _captionController.selection = TextSelection.collapsed(
        offset: _captionController.text.length,
      );
    });
  }

  void _removeTag(Map<String, String> user) {
    setState(() {
      _taggedUsers.removeWhere((u) => u['id'] == user['id']);
      final mentionValue = user['mention'] ?? user['name'] ?? '';
      if (mentionValue.isNotEmpty) {
        _captionController.text = _captionController.text
            .replaceAll('@$mentionValue', '')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();
        _captionController.selection = TextSelection.collapsed(
          offset: _captionController.text.length,
        );
      }
    });
  }

  Future<void> _share() async {
    if (!_hasMedia) {
      _message('Önce bir fotoğraf veya video seç.');
      return;
    }
    if (_spotController.text.trim().isEmpty) {
      _message('Çekim noktası adını yaz.');
      return;
    }
    if (PostService.instance.currentUser == null) {
      _message('Paylaşım yapmak için giriş yapmalısın.');
      return;
    }

    setState(() => _loading = true);
    try {
      final ids = _taggedUsers
          .map((u) => u['id'] ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      final names = _taggedUsers
          .map((u) => u['name'] ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (_isVideo) {
        await PostService.instance.createVideoPost(
          video: _video!,
          caption: _captionController.text,
          spotName: _spotController.text,
          latitude: _latitude,
          longitude: _longitude,
          taggedUserIds: ids,
          taggedUserNames: names,
          businessVenueKey: widget.businessVenueKey,
          businessVenueName: widget.businessVenueName,
        );
      } else {
        await PostService.instance.createPost(
          image: _image!,
          caption: _captionController.text,
          spotName: _spotController.text,
          latitude: _latitude,
          longitude: _longitude,
          taggedUserIds: ids,
          taggedUserNames: names,
          businessVenueKey: widget.businessVenueKey,
          businessVenueName: widget.businessVenueName,
        );
      }
      if (!mounted) return;
      _message(
        _isVideo
            ? 'Video başarıyla paylaşıldı! 🎬'
            : 'Fotoğraf başarıyla paylaşıldı! 📸',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _message(
          'Paylaşım başarısız: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _mediaPreview() {
    if (_video != null) {
      return AppVideoPlayer.file(
        file: _video!,
        autoplay: true,
        muted: true,
        loop: true,
        fit: BoxFit.cover,
      );
    }
    if (_image != null) {
      return Image.file(
        _image!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      );
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_to_photos_outlined, color: Color(0xFFB7BCC2), size: 68),
        SizedBox(height: 14),
        Text(
          'Fotoğraf veya video ekle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text(
          'Video en fazla 30 saniye',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB7BCC2);
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: Text(
          widget.businessVenueName.isEmpty
              ? 'Paylaş'
              : '${widget.businessVenueName} adına paylaş',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: [
          GestureDetector(
            onTap: _chooseSource,
            child: Container(
              height: 330,
              decoration: BoxDecoration(
                color: const Color(0xFF121416),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x334B5158)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _mediaPreview(),
            ),
          ),
          if (_hasMedia) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_isVideo)
                  const Expanded(
                    child: Text(
                      'Video paylaşılırken 720p hazırlanacak.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                else
                  const Spacer(),
                TextButton.icon(
                  onPressed: _loading ? null : _chooseSource,
                  icon: const Icon(Icons.edit),
                  label: Text(
                    _isVideo ? 'Videoyu değiştir' : 'Fotoğrafı değiştir',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _spotController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Çekim noktası adı',
              hintText: 'Örn. Galata Köprüsü',
              prefixIcon: const Icon(Icons.place_outlined, color: accent),
              filled: true,
              fillColor: const Color(0xFF121416),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121416),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x334B5158)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _captionController,
                  maxLines: 4,
                  maxLength: 500,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText:
                        'Paylaşımını anlat, istersen arkadaşını etiketle…',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 70),
                      child: Icon(Icons.notes, color: accent),
                    ),
                    border: InputBorder.none,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _addTag,
                        icon: const Icon(
                          Icons.alternate_email_rounded,
                          size: 18,
                        ),
                        label: const Text('Kişi etiketle'),
                      ),
                      const Spacer(),
                      Text(
                        '${_captionController.text.length}/500',
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_taggedUsers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _taggedUsers
                  .map(
                    (user) => InputChip(
                      avatar: const Icon(
                        Icons.alternate_email_rounded,
                        size: 16,
                      ),
                      label: Text(user['name'] ?? 'Kullanıcı'),
                      onDeleted: _loading ? null : () => _removeTag(user),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation || _loading ? null : _getLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _latitude != null
                          ? Icons.location_on
                          : Icons.location_on_outlined,
                    ),
              label: Text(
                _latitude == null ? 'Konumumu Ekle' : 'Konum Eklendi ✓',
              ),
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: _loading ? null : _share,
              icon: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Icon(
                      _isVideo ? Icons.video_call_rounded : Icons.send_rounded,
                    ),
              label: Text(
                _loading
                    ? (_isVideo ? 'Video hazırlanıyor…' : 'Paylaşılıyor…')
                    : 'Paylaş',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
