import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iris_camera/iris_camera.dart' as iris;

import 'ai_edit_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final iris.IrisCamera _camera = iris.IrisCamera();
  final ImagePicker _picker = ImagePicker();

  List<iris.CameraLensDescriptor> _lenses = const [];
  int _lensIndex = 0;

  bool _initializing = true;
  bool _takingPhoto = false;
  bool _showGrid = true;
  String? _cameraError;

  iris.PhotoFlashMode _flashMode = iris.PhotoFlashMode.off;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final lenses = await _camera.listAvailableLenses();
      if (lenses.isEmpty) {
        if (!mounted) return;
        setState(() {
          _lenses = const [];
          _initializing = false;
          _cameraError = 'Kullanılabilir kamera bulunamadı.';
        });
        return;
      }

      await _camera.switchLens(lenses.first.category);
      await _camera.initialize();

      try {
        await _camera.setExposureMode(iris.ExposureMode.auto);
      } catch (_) {}
      try {
        await _camera.setFocusMode(iris.FocusMode.auto);
      } catch (_) {}
      try {
        await _camera.setExposureOffset(0);
      } catch (_) {}
      try {
        await _camera.setZoom(1.0);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _lenses = lenses;
        _lensIndex = 0;
        _initializing = false;
        _cameraError = null;
      });
    } catch (e) {
      debugPrint('Iris kamera başlatma hatası: $e');
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'Kamera başlatılamadı.';
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto || _initializing) return;

    setState(() => _takingPhoto = true);

    try {
      // Tek dokunuş = tek Iris capture. Kamera oturumunu pause/resume veya
      // dispose/initialize ederek arka arkaya yeniden tetiklemiyoruz.
      final bytes = await _camera.capturePhoto(
        options: iris.PhotoCaptureOptions(
          flashMode: _flashMode,
        ),
      );

      if (bytes.isEmpty) {
        throw Exception('Kamera boş fotoğraf verisi döndürdü.');
      }

      final file = File(
        '${Directory.systemTemp.path}/tbt_iris_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Fotoğraf dosyası oluşturulamadı.');
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiEditScreen(originalImagePath: file.path),
        ),
      );
    } catch (e) {
      debugPrint('Iris fotoğraf çekme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf çekilemedi. Kamerayı tekrar açıp deneyebilirsin.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _takingPhoto = false);
      } else {
        _takingPhoto = false;
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_takingPhoto || _initializing || _lenses.length < 2) return;

    final next = (_lensIndex + 1) % _lenses.length;
    try {
      await _camera.switchLens(_lenses[next].category);
      if (!mounted) return;
      setState(() => _lensIndex = next);
    } catch (e) {
      debugPrint('Lens değiştirme hatası: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_takingPhoto) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 94,
      );
      if (image == null || !mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiEditScreen(originalImagePath: image.path),
        ),
      );
    } catch (e) {
      debugPrint('Galeri hatası: $e');
    }
  }

  void _cycleFlashMode() {
    if (_takingPhoto) return;
    setState(() {
      _flashMode = switch (_flashMode) {
        iris.PhotoFlashMode.off => iris.PhotoFlashMode.auto,
        iris.PhotoFlashMode.auto => iris.PhotoFlashMode.on,
        iris.PhotoFlashMode.on => iris.PhotoFlashMode.off,
      };
    });
  }

  IconData get _flashIcon => switch (_flashMode) {
        iris.PhotoFlashMode.off => Icons.flash_off_rounded,
        iris.PhotoFlashMode.auto => Icons.flash_auto_rounded,
        iris.PhotoFlashMode.on => Icons.flash_on_rounded,
      };

  String get _flashLabel => switch (_flashMode) {
        iris.PhotoFlashMode.off => 'Kapalı',
        iris.PhotoFlashMode.auto => 'Otomatik',
        iris.PhotoFlashMode.on => 'Açık',
      };

  Future<void> _focusAt(TapDownDetails details, BoxConstraints constraints) async {
    if (_takingPhoto || constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
      return;
    }

    final point = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );

    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: point);
      await _camera.setExposurePoint(point);
    } catch (e) {
      debugPrint('Odaklama hatası: $e');
    }
  }

  @override
  void dispose() {
    _camera.disposeSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC107)),
        ),
      );
    }

    if (_cameraError != null || _lenses.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.no_photography_outlined,
                          size: 54,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _cameraError ?? 'Kamera başlatılamadı.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _initializing = true;
                              _cameraError = null;
                            });
                            _initializeCamera();
                          },
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cycleFlashMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_flashIcon, color: Colors.white, size: 19),
                          const SizedBox(width: 6),
                          Text(
                            _flashLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(
                    icon: _showGrid ? Icons.grid_on : Icons.grid_off,
                    onTap: () => setState(() => _showGrid = !_showGrid),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _focusAt(details, constraints),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(
                              color: Colors.black,
                              child: iris.IrisCameraPreview(
                                enableTapToFocus: false,
                                showFocusIndicator: false,
                              ),
                            ),
                            if (_showGrid)
                              const IgnorePointer(child: _CameraGrid()),
                            if (_takingPhoto)
                              Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFFC107),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.photo_library_outlined,
                    size: 56,
                    onTap: _pickFromGallery,
                  ),
                  GestureDetector(
                    onTap: _takingPhoto ? null : _takePhoto,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: _takingPhoto ? 0.55 : 1,
                      child: Container(
                        width: 86,
                        height: 86,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _CircleButton(
                    icon: Icons.cameraswitch_outlined,
                    size: 56,
                    onTap: _toggleCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white10,
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: size * .48),
      ),
    );
  }
}

class _CameraGrid extends StatelessWidget {
  const _CameraGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CameraGridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.28)
      ..strokeWidth = 1;

    final x1 = size.width / 3;
    final x2 = size.width * 2 / 3;
    final y1 = size.height / 3;
    final y2 = size.height * 2 / 3;

    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), paint);
    canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), paint);
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), paint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
