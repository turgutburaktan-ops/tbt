import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/story_service.dart';
import '../theme/app_theme.dart';
import 'camera_video_post_screen.dart';
import 'create_post_screen.dart';
import 'story_photo_editor_screen.dart';

class CameraScreen extends StatefulWidget {
  final bool storyMode;

  const CameraScreen({super.key, this.storyMode = false});

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

  int get _videoLimitSeconds => widget.storyMode ? 15 : 60;

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
      if (!mounted) return;
      setState(() {
        _opening = false;
        _returningFromCamera = false;
      });
      final shared = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => StoryPhotoEditorScreen(photo: photo),
        ),
      );
      if (!mounted) return;
      if (shared == true) {
        Navigator.pop(context, true);
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
      MaterialPageRoute(builder: (_) => CameraVideoPostScreen(video: video)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storyMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _opening ? _buildStoryProgress() : _buildStoryLauncher(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kamera')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _opening ? _buildProgress() : _buildLauncher(),
        ),
      ),
    );
  }

  Widget _buildStoryLauncher() {
    return Stack(
      key: const ValueKey('story_launcher'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                center: const Alignment(0, -.15),
                colors: [
                  const Color(0xFF252A31),
                  Colors.black.withValues(alpha: .96),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    _StoryTopButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context, false),
                    ),
                    const Spacer(),
                    const Text(
                      'Story',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    _StoryTopButton(
                      icon: Icons.photo_library_outlined,
                      onTap: _openGallery,
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .08),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white54,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fotoğraf veya video çek',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fotoğrafı çektikten sonra yazı, font ve emoji ekleyebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: .30),
                      ),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StoryModeButton(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      onTap: _captureVideo,
                    ),
                    const SizedBox(width: 28),
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        width: 82,
                        height: 82,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    _StoryModeButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Galeri',
                      onTap: _openGallery,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Fotoğraf',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryProgress() {
    final preparing = _returningFromCamera;
    final action = _currentAction.isEmpty ? 'Medya' : _currentAction;
    return ColoredBox(
      key: const ValueKey('story_progress'),
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 18),
                Text(
                  preparing
                      ? '$action hazırlanıyor…'
                      : 'Kamera tam ekran açılıyor…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (preparing && _currentAction == 'Fotoğraf') ...[
                  const SizedBox(height: 7),
                  const Text(
                    'Birazdan Story düzenleme ekranı açılacak.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
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
              const Text(
                'Hazır olur olmaz paylaşım ekranı açılacak.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
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
              const Text(
                'Ne çekmek istiyorsun?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Telefonunun kendi kamerasıyla fotoğraf veya en fazla 30 saniyelik video çek.',
                textAlign: TextAlign.center,
                style: TextStyle(
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
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

class _StoryTopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StoryTopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black45,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: Colors.white),
      ),
    ),
  );
}

class _StoryModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StoryModeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black45,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
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
              style: const TextStyle(color: Color(0x75FFFFFF), fontSize: 10.5),
            ),
          ],
        ),
      ),
    ),
  );
}
