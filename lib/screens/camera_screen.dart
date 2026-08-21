import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/story_service.dart';
import '../theme/app_theme.dart';
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Galeriden yükle',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              ListTile(
                dense: true,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Fotoğraf seç'),
                onTap: () => Navigator.pop(sheetContext, 'photo'),
              ),
              ListTile(
                dense: true,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.cyan,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              preparing
                  ? '$action hazırlanıyor…\nLütfen bekleyin.'
                  : 'Telefonun orijinal kamerası açılıyor…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (preparing) ...[
              const SizedBox(height: 8),
              Text(
                widget.storyMode
                    ? 'Hazır olur olmaz Story paylaşılacak.'
                    : 'Hazır olur olmaz paylaşım ekranı açılacak.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLauncher() {
    return Center(
      key: const ValueKey('launcher'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.camera_rounded,
                  size: 29,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.storyMode ? 'Story oluştur' : 'Ne çekmek istiyorsun?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.storyMode
                    ? 'Fotoğraf veya en fazla 15 saniyelik video çek. İstersen galeriden yükle.'
                    : 'Telefonunun kendi kamerasıyla fotoğraf veya en fazla 30 saniyelik video çek.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.liked.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppColors.liked.withValues(alpha: .30),
                    ),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ),
              ],
              const SizedBox(height: 24),
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
                  const SizedBox(width: 10),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 19),
                  label: const Text('Galeriden Yükle'),
                ),
              ),
            ],
          ),
        ),
      ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 23, color: AppColors.cyan),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white46,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
