import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/retention_hub_quick_entry.dart';
import 'camera_video_post_screen.dart';
import 'create_post_screen.dart';

class MainCameraScreen extends StatefulWidget {
  const MainCameraScreen({super.key});

  @override
  State<MainCameraScreen> createState() => _MainCameraScreenState();
}

class _MainCameraScreenState extends State<MainCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  String? _error;

  static const int _videoLimitSeconds = 60;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _photo(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreatePostScreen(initialImagePath: picked.path),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Fotoğraf açılamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _video(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await _picker.pickVideo(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxDuration: const Duration(seconds: _videoLimitSeconds),
      );
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      if (!await file.exists() || await file.length() <= 0) {
        throw Exception('Video dosyası okunamadı.');
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CameraVideoPostScreen(video: file)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Video açılamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Fotoğraf seç'),
            onTap: () => Navigator.pop(sheet, 'photo'),
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('Video seç'),
            subtitle: const Text('En fazla 1 dakika'),
            onTap: () => Navigator.pop(sheet, 'video'),
          ),
        ],
      ),
    );
    if (kind == 'photo') await _photo(ImageSource.gallery);
    if (kind == 'video') await _video(ImageSource.gallery);
  }

  @override
  Widget build(BuildContext context) {
    return RetentionHubQuickEntry(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Kamera')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.accentGradient,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ne çekmek istiyorsun?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Fotoğraf çek veya 1 dakikaya kadar video/Reels oluştur.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, height: 1.4),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _photo(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Fotoğraf Çek'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _video(ImageSource.camera),
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Video / Reels Çek • 1 dk'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _gallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galeriden Seç'),
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
