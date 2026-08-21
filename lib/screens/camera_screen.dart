import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/story_service.dart';
import 'camera_video_post_screen.dart';
import 'create_post_screen.dart';

class CameraScreen extends StatefulWidget {
  final bool storyMode;

  const CameraScreen({
    super.key,
    this.storyMode = false,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  bool _opening = false;
  bool _returningFromCamera = false;
  String _currentAction = '';
  String? _error;

  int get _videoLimitSeconds => widget.storyMode ? 15 : 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _opening && mounted) {
      setState(() => _returningFromCamera = true);
    }
  }

  Future<void> _capturePhoto() async {
    if (_opening) return;
    _startOpening('Fotoğraf');
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (photo == null || !mounted) {
        _finishOpening();
        return;
      }
      await _handlePhoto(File(photo.path));
    } catch (error) {
      _showError('Telefon kamerası açılamadı: $error');
    }
  }

  Future<void> _captureVideo() async {
    if (_opening) return;
    _startOpening('Video');
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxDuration: Duration(seconds: _videoLimitSeconds),
      );
      if (video == null || !mounted) {
        _finishOpening();
        return;
      }
      await _handleVideo(File(video.path));
    } catch (error) {
      _showError('Telefon kamerasında video açılamadı: $error');
    }
  }

  Future<void> _openGallery() async {
    if (_opening) return;
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111317),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Galeriden yükle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Fotoğraf seç'),
                onTap: () => Navigator.pop(sheetContext, 'photo'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Video seç'),
                subtitle: Text('En fazla $_videoLimitSeconds saniye'),
                onTap: () => Navigator.pop(sheetContext, 'video'),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;

    _startOpening(type == 'video' ? 'Video' : 'Fotoğraf');
    try {
      if (type == 'video') {
        final video = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: Duration(seconds: _videoLimitSeconds),
        );
        if (video == null || !mounted) {
          _finishOpening();
          return;
        }
        await _handleVideo(File(video.path));
      } else {
        final photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 100,
          requestFullMetadata: false,
        );
        if (photo == null || !mounted) {
          _finishOpening();
          return;
        }
        await _handlePhoto(File(photo.path));
      }
    } catch (error) {
      _showError('Galeri açılamadı: $error');
    }
  }

  void _startOpening(String action) {
    setState(() {
      _opening = true;
      _returningFromCamera = false;
      _currentAction = action;
      _error = null;
    });
  }

  void _finishOpening() {
    if (!mounted) return;
    setState(() {
      _opening = false;
      _returningFromCamera = false;
      _currentAction = '';
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _opening = false;
      _returningFromCamera = false;
      _error = message;
    });
  }

  Future<void> _handlePhoto(File photo) async {
    if (widget.storyMode) {
      try {
        setState(() => _returningFromCamera = true);
        await StoryService.instance.createStory(photo);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (error) {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialImagePath: photo.path),
      ),
    );
  }

  Future<void> _handleVideo(File video) async {
    if (widget.storyMode) {
      try {
        setState(() => _returningFromCamera = true);
        await StoryService.instance.createVideoStory(video);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (error) {
        _showError(error.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CameraVideoPostScreen(video: video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.storyMode ? 'Story Kamerası' : 'Kamera';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _opening ? _buildProgress() : _buildLauncher(),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final preparing = _returningFromCamera;
    final action = _currentAction.isEmpty ? 'Medya' : _currentAction;
    return Center(
      key: const ValueKey('progress'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              preparing
                  ? '$action hazırlanıyor…\nLütfen bekleyin.'
                  : 'Telefonun orijinal kamerası açılıyor…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.35,
              ),
            ),
            if (preparing) ...[
              const SizedBox(height: 10),
              Text(
                widget.storyMode
                    ? 'Hazır olur olmaz Story paylaşılacak.'
                    : 'Hazır olur olmaz paylaşım ekranı açılacak.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLauncher() {
    return ListView(
      key: const ValueKey('launcher'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      children: [
        const Icon(Icons.camera_rounded, size: 74, color: Colors.white),
        const SizedBox(height: 14),
        Text(
          widget.storyMode ? 'Story oluştur' : 'Ne çekmek istiyorsun?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          widget.storyMode
              ? 'Fotoğraf veya en fazla 15 saniyelik video çek. İstersen galeriden yükle.'
              : 'Telefonunun kendi kamerasıyla fotoğraf veya en fazla 30 saniyelik video çek.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, height: 1.4),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: .35)),
            ),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: _CaptureButton(
                icon: Icons.photo_camera_rounded,
                title: 'Fotoğraf',
                subtitle: 'Telefon kamerası',
                onTap: _capturePhoto,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CaptureButton(
                icon: Icons.videocam_rounded,
                title: 'Video',
                subtitle: '$_videoLimitSeconds sn',
                onTap: _captureVideo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 58,
          child: OutlinedButton.icon(
            onPressed: _openGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galeriden Yükle'),
          ),
        ),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CaptureButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF13161A),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
            child: Column(
              children: [
                Icon(icon, size: 38, color: Colors.white),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white46, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}
