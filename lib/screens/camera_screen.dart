import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iris_camera/iris_camera.dart' as iris;
import 'package:sensors_plus/sensors_plus.dart';

import '../services/ai_service.dart';
import 'ai_edit_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _ModeProfile {
  final int iso;
  final int shutterDenominator;
  final double ev;
  final double zoom;
  final String hint;

  const _ModeProfile(
    this.iso,
    this.shutterDenominator,
    this.ev,
    this.zoom,
    this.hint,
  );
}

class _CameraScreenState extends State<CameraScreen> {
  final iris.IrisCamera _camera = iris.IrisCamera();
  final ImagePicker _picker = ImagePicker();

  List<iris.CameraLensDescriptor> _lenses = [];
  int _lensIndex = 0;
  bool _initializing = true;
  bool _takingPhoto = false;
  bool _aiBusy = false;
  bool _aiEnabled = false;
  bool _showGrid = true;
  bool _locked = false;
  Offset? _focusPoint;

  String _mode = 'Normal';
  String _tip = 'Hazır';
  int _iso = 100;
  int _shutter = 125;
  double _ev = 0;
  double _zoom = 1;
  double _movement = 0;

  iris.PhotoFlashMode _flash = iris.PhotoFlashMode.auto;
  StreamSubscription<AccelerometerEvent>? _motionSub;

  static const modes = [
    'Normal',
    'Portre',
    'Manzara',
    'Spor',
    'Gece',
    'Makro',
  ];

  _ModeProfile get _profile {
    switch (_mode) {
      case 'Portre':
        return const _ModeProfile(
          100,
          250,
          0.0,
          1.2,
          'Portre • yüz ve göz netliği öncelikli',
        );
      case 'Manzara':
        return const _ModeProfile(
          100,
          160,
          -0.10,
          1.0,
          'Manzara • gökyüzünü ve uzak detayları koru',
        );
      case 'Spor':
        return const _ModeProfile(
          320,
          1000,
          0.0,
          1.0,
          'Spor • hareketi dondur, hızlı shutter öncelikli',
        );
      case 'Gece':
        return const _ModeProfile(
          640,
          30,
          0.08,
          1.0,
          'Gece • telefonu sabit tut, ışıkları patlatma',
        );
      case 'Makro':
        return const _ModeProfile(
          125,
          250,
          -0.05,
          1.0,
          'Makro • nesneye yaklaş ve dokunarak netle',
        );
      default:
        return const _ModeProfile(
          100,
          125,
          0.0,
          1.0,
          'Normal • hızlı ve güvenli otomatik AF/AE',
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
    _motionSub = accelerometerEventStream().listen((event) {
      _movement =
          (sqrt(event.x * event.x + event.y * event.y + event.z * event.z) -
                  9.81)
              .abs();
    });
  }

  Future<void> _init() async {
    try {
      _lenses = await _camera.listAvailableLenses();
      if (_lenses.isNotEmpty) {
        await _camera.switchLens(_lenses.first.category);
        await _camera.initialize();
        await _applyMode();
      }
    } catch (e) {
      debugPrint('camera init: $e');
    }
    if (mounted) setState(() => _initializing = false);
  }

  Future<double> _safeEv(double wanted) async {
    double minEv = -2;
    double maxEv = 2;
    try {
      minEv = await _camera.getMinExposureOffset();
      maxEv = await _camera.getMaxExposureOffset();
    } catch (_) {}
    return wanted
        .clamp(max(-0.75, minEv), min(0.55, maxEv))
        .toDouble();
  }

  Future<void> _applyMode() async {
    final p = _profile;
    _iso = p.iso;
    _shutter = p.shutterDenominator;
    _zoom = p.zoom;

    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
    } catch (_) {}
    try {
      await _camera.setFocusMode(
        _locked ? iris.FocusMode.locked : iris.FocusMode.auto,
      );
    } catch (_) {}

    final ev = await _safeEv(p.ev);
    try {
      await _camera.setExposureOffset(ev);
    } catch (_) {}
    try {
      await _camera.setZoom(p.zoom);
    } catch (_) {}
    if (_focusPoint != null) {
      try {
        await _camera.setFocus(point: _focusPoint!);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _ev = ev;
        _tip = p.hint;
      });
    }
  }

  Future<void> _tapFocus(TapDownDetails details, BoxConstraints c) async {
    if (_locked) return;
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    _focusPoint = point;
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: point);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _longPressLock(
    LongPressStartDetails details,
    BoxConstraints c,
  ) async {
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    _focusPoint = point;
    _locked = true;
    try {
      // Focus is locked, exposure deliberately remains automatic.
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setFocus(point: point);
      await _camera.setFocusMode(iris.FocusMode.locked);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _tip = 'ODAK KİLİTLİ • pozlama otomatik • açmak için uzun bas';
      });
    }
  }

  Future<void> _unlock() async {
    _locked = false;
    _focusPoint = null;
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setFocusMode(iris.FocusMode.auto);
    } catch (_) {}
    await _applyMode();
  }

  Future<void> _selectMode(String mode) async {
    if (_takingPhoto) return;
    setState(() {
      _mode = mode;
      _tip = '$mode hazırlanıyor…';
    });
    await _applyMode();
    if (_aiEnabled) unawaited(_analyze());
  }

  Future<File> _capture() async {
    iris.PhotoCaptureOptions options;

    if (_mode == 'Spor') {
      final shutter = _shutter.clamp(500, 1250);
      final iso = _iso.clamp(100, 1600);
      options = iris.PhotoCaptureOptions(
        flashMode: _flash,
        iso: iso.toDouble(),
        exposureDuration: Duration(
          microseconds: max(800, (1000000 / shutter).round()),
        ),
      );
    } else if (_mode == 'Gece' && _movement < 0.65) {
      final shutter = _shutter.clamp(15, 60);
      final iso = _iso.clamp(200, 1600);
      var duration = Duration(
        microseconds: (1000000 / shutter).round(),
      );
      try {
        final maxDuration = await _camera.getMaxExposureDuration();
        if (duration > maxDuration) duration = maxDuration;
      } catch (_) {}
      options = iris.PhotoCaptureOptions(
        flashMode: iris.PhotoFlashMode.off,
        iso: iso.toDouble(),
        exposureDuration: duration,
      );
    } else {
      // Normal, Portrait, Landscape and Macro keep the phone's stable AE.
      options = iris.PhotoCaptureOptions(flashMode: _flash);
    }

    final bytes = await _camera.capturePhoto(options: options);
    if (bytes.isEmpty) throw Exception('empty capture');
    final file = File(
      '${Directory.systemTemp.path}/tbt_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto || _initializing) return;
    setState(() => _takingPhoto = true);
    try {
      final file = await _capture();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiEditScreen(originalImagePath: file.path),
        ),
      );
    } catch (e) {
      debugPrint('capture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf çekilemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _analyze() async {
    if (!_aiEnabled || _aiBusy || _takingPhoto) return;
    setState(() {
      _aiBusy = true;
      _tip = 'AI sahneyi okuyor…';
    });

    File? file;
    try {
      // Analysis frame is captured quickly; network work continues afterwards.
      final bytes = await _camera.capturePhoto(
        options: const iris.PhotoCaptureOptions(
          flashMode: iris.PhotoFlashMode.off,
        ),
      );
      file = File(
        '${Directory.systemTemp.path}/ai_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);

      final analysis = await AiService.analyzeLiveFrame(
        imagePath: file.path,
        mode: _mode,
      );

      final targetEv = await _safeEv(analysis.recommendedEv);
      final targetIso = analysis.recommendedIso.clamp(50, 1600);
      final targetShutter =
          analysis.recommendedShutterDenominator.clamp(15, 1250);

      try {
        await _camera.setExposureMode(iris.ExposureMode.auto);
        await _camera.setExposureOffset(targetEv);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _ev = targetEv;
          _iso = targetIso;
          _shutter = targetShutter;
          _tip = analysis.mainTip.isEmpty ? _profile.hint : analysis.mainTip;
        });
      }
    } catch (e) {
      debugPrint('AI camera: $e');
      if (mounted) setState(() => _tip = _profile.hint);
    } finally {
      if (file != null) {
        try {
          await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _toggleAi() async {
    if (_takingPhoto) return;
    setState(() => _aiEnabled = !_aiEnabled);
    if (_aiEnabled) {
      unawaited(_analyze());
    } else {
      await _applyMode();
    }
  }

  Future<void> _toggleLens() async {
    if (_lenses.length < 2 || _takingPhoto) return;
    _lensIndex = (_lensIndex + 1) % _lenses.length;
    try {
      await _camera.switchLens(_lenses[_lensIndex].category);
      await _applyMode();
    } catch (e) {
      debugPrint('lens switch: $e');
    }
  }

  Future<void> _gallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 94,
    );
    if (image != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiEditScreen(originalImagePath: image.path),
        ),
      );
    }
  }

  void _cycleFlash() {
    setState(() {
      _flash = _flash == iris.PhotoFlashMode.off
          ? iris.PhotoFlashMode.auto
          : _flash == iris.PhotoFlashMode.auto
              ? iris.PhotoFlashMode.on
              : iris.PhotoFlashMode.off;
    });
  }

  @override
  void dispose() {
    _motionSub?.cancel();
    _camera.disposeSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_lenses.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Kamera başlatılamadı',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _top(),
            Expanded(child: _preview()),
            _hud(),
            _modes(),
            _bottom(),
          ],
        ),
      ),
    );
  }

  Widget _top() {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          _circle(Icons.close, () => Navigator.pop(context)),
          Expanded(
            child: GestureDetector(
              onTap: _toggleAi,
              child: Container(
                height: 44,
                margin: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _aiEnabled
                      ? const Color(0xFFFFC107)
                      : const Color(0xFF151A22),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  _aiBusy ? '✨ AI AYARLIYOR…' : '✨ AI AUTO PRO',
                  style: TextStyle(
                    color: _aiEnabled ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          _circle(
            _flash == iris.PhotoFlashMode.off
                ? Icons.flash_off
                : _flash == iris.PhotoFlashMode.auto
                    ? Icons.flash_auto
                    : Icons.flash_on,
            _cycleFlash,
          ),
          _circle(
            _showGrid ? Icons.grid_on : Icons.grid_off,
            () => setState(() => _showGrid = !_showGrid),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (_, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _tapFocus(d, constraints),
                onLongPressStart: (d) =>
                    _locked ? _unlock() : _longPressLock(d, constraints),
                child: const iris.IrisCameraPreview(
                  enableTapToFocus: false,
                  showFocusIndicator: false,
                ),
              ),
            ),
            if (_showGrid) const IgnorePointer(child: _Grid()),
            if (_focusPoint != null)
              LayoutBuilder(
                builder: (_, c) => Positioned(
                  left: _focusPoint!.dx * c.maxWidth - 24,
                  top: _focusPoint!.dy * c.maxHeight - 24,
                  child: IgnorePointer(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFFFC107),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _locked
                          ? const Icon(
                              Icons.lock,
                              color: Color(0xFFFFC107),
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 18,
              right: 18,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.68),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _tip,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hud() {
    return Container(
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF11151C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _param('MOD', _mode),
          _param(_aiEnabled ? 'AI ISO' : 'ISO', _aiEnabled ? '$_iso' : 'AUTO'),
          _param(_aiEnabled ? 'AI S' : 'S', _aiEnabled ? '1/$_shutter' : 'AUTO'),
          _param('ODAK', _locked ? 'AF-L' : 'AF'),
          _param('EV', '${_ev >= 0 ? '+' : ''}${_ev.toStringAsFixed(1)}'),
        ],
      ),
    );
  }

  Widget _modes() {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final mode = modes[i];
          final selected = mode == _mode;
          return GestureDetector(
            onTap: () => _selectMode(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFC107)
                    : const Color(0xFF151A22),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bottom() {
    return SizedBox(
      height: 112,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _circle(Icons.photo_library_outlined, _gallery, size: 56),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: 84,
              height: 84,
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
                child: _takingPhoto
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Colors.black),
                      )
                    : null,
              ),
            ),
          ),
          _circle(Icons.cameraswitch_outlined, _toggleLens, size: 56),
        ],
      ),
    );
  }

  Widget _circle(IconData icon, VoidCallback? onTap, {double size = 44}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF151A22),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _param(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: label == 'EV' ? const Color(0xFFFFC107) : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.25)
      ..strokeWidth = 1;
    for (final x in [size.width / 3, size.width * 2 / 3]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (final y in [size.height / 3, size.height * 2 / 3]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
