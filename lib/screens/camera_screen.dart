import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'create_post_screen.dart';

/// Opens the phone manufacturer's camera application and passes its original
/// output file directly to TBT. TBT does not filter, crop, resize or re-encode
/// the captured photo.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  bool _opening = false;
  bool _returningFromCamera = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSystemCamera());
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

  Future<void> _openSystemCamera() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _returningFromCamera = false;
      _error = null;
    });

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;
      if (photo == null) {
        Navigator.of(context).pop();
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CreatePostScreen(initialImagePath: photo.path),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _returningFromCamera = false;
        _error = 'Telefon kamerası açılamadı: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Kamera'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _error == null
              ? Column(
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
                      _returningFromCamera
                          ? 'Fotoğraf hazırlanıyor…\nLütfen bekleyin.'
                          : 'Telefonun orijinal kamerası açılıyor…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    if (_returningFromCamera) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Fotoğraf hazır olur olmaz paylaşım ekranı açılacak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white54,
                      size: 54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _openSystemCamera,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
