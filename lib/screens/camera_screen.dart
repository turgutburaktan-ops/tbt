import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:iris_camera/iris_camera.dart' as iris;
import 'package:sensors_plus/sensors_plus.dart';

import 'photo_review_screen.dart';

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

class _FilterPreset {
  final String name;
  final double contrast;
  final double saturation;
  final double brightness;
  final double gamma;
  final double hue;
  final double vignette;
  final List<double> matrix;
  final List<Color> colors;
  final Color overlay;

  const _FilterPreset({
    required this.name,
    this.contrast = 1,
    this.saturation = 1,
    this.brightness = 1,
    this.gamma = 1,
    this.hue = 0,
    this.vignette = 0,
    required this.matrix,
    required this.colors,
    this.overlay = Colors.transparent,
  });
}

const List<double> _identityMatrix = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

const List<_FilterPreset> _presets = <_FilterPreset>[
  _FilterPreset(
    name: 'Natural',
    matrix: _identityMatrix,
    colors: [Color(0xFF576574), Color(0xFF1E272E)],
  ),
  _FilterPreset(
    name: 'Soft Clean',
    contrast: 0.96,
    saturation: 0.92,
    brightness: 1.04,
    gamma: 0.97,
    matrix: <double>[
      1.04, 0, 0, 0, 5,
      0, 1.03, 0, 0, 4,
      0, 0, 1.02, 0, 5,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFC9D6DF), Color(0xFF52616B)],
    overlay: Color(0x0CFFFFFF),
  ),
  _FilterPreset(
    name: 'Warm Street',
    contrast: 1.08,
    saturation: 1.08,
    brightness: 1.01,
    gamma: 0.98,
    hue: -2,
    vignette: .18,
    matrix: <double>[
      1.10, 0, 0, 0, 2,
      0, 1.02, 0, 0, 0,
      0, 0, .90, 0, -2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFF39C12), Color(0xFF6D4C41)],
    overlay: Color(0x12FF8A00),
  ),
  _FilterPreset(
    name: 'Golden',
    contrast: 1.10,
    saturation: 1.14,
    brightness: 1.02,
    gamma: 0.96,
    hue: -4,
    vignette: .14,
    matrix: <double>[
      1.14, 0, 0, 0, 3,
      0, 1.05, 0, 0, 1,
      0, 0, .84, 0, -2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFFFB347), Color(0xFF7D4E00)],
    overlay: Color(0x18FFB300),
  ),
  _FilterPreset(
    name: 'Cine',
    contrast: 1.16,
    saturation: .88,
    brightness: .98,
    gamma: 1.03,
    hue: 3,
    vignette: .28,
    matrix: <double>[
      .94, 0, .04, 0, -1,
      0, 1.01, .02, 0, 0,
      .02, 0, 1.09, 0, 2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF34495E), Color(0xFF0C2461)],
    overlay: Color(0x12006A8E),
  ),
  _FilterPreset(
    name: 'Night Glow',
    contrast: 1.18,
    saturation: 1.12,
    brightness: 1.03,
    gamma: .96,
    hue: 4,
    vignette: .22,
    matrix: <double>[
      .94, 0, .03, 0, 0,
      0, 1.02, .02, 0, 0,
      .03, 0, 1.13, 0, 2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF1B1464), Color(0xFF0652DD)],
    overlay: Color(0x12003D9E),
  ),
  _FilterPreset(
    name: 'Forest',
    contrast: 1.08,
    saturation: 1.06,
    brightness: .98,
    gamma: 1.02,
    hue: 2,
    vignette: .16,
    matrix: <double>[
      .92, 0, 0, 0, 0,
      0, 1.10, 0, 0, 1,
      0, .02, .92, 0, 0,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF2D6A4F), Color(0xFF081C15)],
    overlay: Color(0x10006435),
  ),
  _FilterPreset(
    name: 'Matte',
    contrast: .92,
    saturation: .86,
    brightness: 1.02,
    gamma: 1.04,
    matrix: <double>[
      .96, 0, 0, 0, 9,
      0, .96, 0, 0, 9,
      0, 0, .98, 0, 10,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFA5B1C2), Color(0xFF4B6584)],
    overlay: Color(0x0AFFFFFF),
  ),
  _FilterPreset(
    name: 'Portrait Soft',
    contrast: .98,
    saturation: .96,
    brightness: 1.04,
    gamma: .97,
    hue: -2,
    matrix: <double>[
      1.07, 0, 0, 0, 3,
      0, 1.02, 0, 0, 2,
      0, 0, .98, 0, 2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFFFC1C8), Color(0xFF8E5A63)],
    overlay: Color(0x10FF8FA3),
  ),
  _FilterPreset(
    name: 'Urban Cool',
    contrast: 1.12,
    saturation: .92,
    brightness: .99,
    gamma: 1.02,
    hue: 4,
    vignette: .12,
    matrix: <double>[
      .91, 0, .02, 0, 0,
      0, .99, .02, 0, 0,
      .02, 0, 1.11, 0, 2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF778CA3), Color(0xFF2C3A47)],
    overlay: Color(0x10004C8A),
  ),
  _FilterPreset(
    name: 'Vintage',
    contrast: .96,
    saturation: .82,
    brightness: 1.02,
    gamma: 1.02,
    hue: -6,
    vignette: .25,
    matrix: <double>[
      1.07, 0, 0, 0, 4,
      0, .98, 0, 0, 2,
      0, 0, .84, 0, 1,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFC8A165), Color(0xFF5D4037)],
    overlay: Color(0x12A76521),
  ),
  _FilterPreset(
    name: 'Mono',
    contrast: 1.12,
    saturation: 0,
    brightness: 1.01,
    gamma: 1.01,
    vignette: .18,
    matrix: <double>[
      .2126, .7152, .0722, 0, 0,
      .2126, .7152, .0722, 0, 0,
      .2126, .7152, .0722, 0, 0,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFB2BEC3), Color(0xFF2D3436)],
    overlay: Color(0x08000000),
  ),
];

class _CameraScreenState extends State<CameraScreen> {
  final iris.IrisCamera _camera = iris.IrisCamera();
  final ImagePicker _picker = ImagePicker();

  List<iris.CameraLensDescriptor> _lenses = [];
  int _lensIndex = 0;
  bool _initializing = true;
  bool _takingPhoto = false;
  bool _processingPreset = false;
  bool _showGrid = true;
  bool _locked = false;
  Offset? _focusPoint;

  String _mode = 'Fotoğraf';
  String _tip = 'Hazır';
  int _iso = 100;
  int _shutter = 125;
  int _wbKelvin = 5200;
  double _ev = 0;
  double _zoom = 1;
  double _movement = 0;
  String _ratio = '4:3';
  int _timerSeconds = 0;
  int _countdown = 0;
  int _selectedPreset = 0;
  String? _lastShotPath;
  String _activeProControl = 'ISO';

  iris.PhotoFlashMode _flash = iris.PhotoFlashMode.auto;
  StreamSubscription<AccelerometerEvent>? _motionSub;

  static const List<String> modes = ['Fotoğraf', 'Portre', 'Gece', 'Pro'];
  static const List<int> shutterSteps = [15, 30, 60, 125, 250, 500, 1000, 2000];

  _ModeProfile get _profile {
    switch (_mode) {
      case 'Portre':
        return const _ModeProfile(100, 250, 0.0, 1.2, 'Portre • yüz netliği');
      case 'Gece':
        return const _ModeProfile(640, 30, 0.08, 1.0, 'Gece • telefonu sabit tut');
      case 'Pro':
        return const _ModeProfile(400, 60, 0.0, 1.0, 'Pro • manuel çekim');
      default:
        return const _ModeProfile(100, 125, 0.0, 1.0, 'Fotoğraf • otomatik AF/AE');
    }
  }

  _FilterPreset get _preset => _presets[_selectedPreset];

  double get _previewAspectRatio {
    switch (_ratio) {
      case '1:1':
        return 1;
      case '16:9':
        return 9 / 16;
      default:
        return 3 / 4;
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
    _motionSub = accelerometerEventStream().listen((event) {
      _movement =
          (sqrt(event.x * event.x + event.y * event.y + event.z * event.z) - 9.81)
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
    return wanted.clamp(max(-0.75, minEv), min(0.55, maxEv)).toDouble();
  }

  Future<void> _applyMode() async {
    final p = _profile;
    _iso = p.iso;
    _shutter = p.shutterDenominator;
    _zoom = p.zoom;
    _wbKelvin = _mode == 'Gece' ? 4300 : 5200;

    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
    } catch (_) {}
    try {
      await _camera.setFocusMode(_locked ? iris.FocusMode.locked : iris.FocusMode.auto);
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
    if (mounted) setState(() => _tip = 'Odaklandı');
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
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setFocus(point: point);
      await _camera.setFocusMode(iris.FocusMode.locked);
    } catch (_) {}
    if (mounted) setState(() => _tip = 'AF-L • odak kilitli');
  }

  Future<void> _unlock() async {
    _locked = false;
    _focusPoint = null;
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setFocusMode(iris.FocusMode.auto);
    } catch (_) {}
    if (mounted) setState(() => _tip = 'AF • otomatik odak');
  }

  Future<void> _selectMode(String mode) async {
    if (_takingPhoto) return;
    setState(() {
      _mode = mode;
      _tip = '$mode hazırlanıyor…';
      if (mode == 'Pro') _activeProControl = 'ISO';
    });
    await _applyMode();
  }

  Future<void> _setEv(double value) async {
    final safe = await _safeEv(value);
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(safe);
    } catch (_) {}
    if (mounted) setState(() => _ev = safe);
  }

  Future<void> _selectZoom(double value) async {
    try {
      await _camera.setZoom(value);
      if (mounted) setState(() => _zoom = value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${value}x bu lenste desteklenmiyor.')),
      );
    }
  }

  Future<File> _capture() async {
    iris.PhotoCaptureOptions options;

    if (_mode == 'Pro') {
      final shutter = _shutter.clamp(15, 2000);
      final iso = _iso.clamp(50, 1600);
      var duration = Duration(microseconds: max(500, (1000000 / shutter).round()));
      try {
        final maxDuration = await _camera.getMaxExposureDuration();
        if (duration > maxDuration) duration = maxDuration;
      } catch (_) {}
      options = iris.PhotoCaptureOptions(
        flashMode: _flash,
        iso: iso.toDouble(),
        exposureDuration: duration,
      );
    } else if (_mode == 'Gece' && _movement < 0.65) {
      final shutter = _shutter.clamp(15, 60);
      final iso = _iso.clamp(200, 1600);
      var duration = Duration(microseconds: (1000000 / shutter).round());
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

  Future<File> _renderPreset(File original) async {
    final p = _preset;
    final wbShift = ((_wbKelvin - 5200) / 1000).clamp(-2.4, 2.4).toDouble();
    final unchanged = _selectedPreset == 0 && wbShift.abs() < .15;
    if (unchanged) return original;

    final output = File(
      '${Directory.systemTemp.path}/tbt_render_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final command = img.Command()
      ..decodeImageFile(original.path)
      ..bakeOrientation()
      ..adjustColor(
        contrast: p.contrast,
        saturation: p.saturation,
        brightness: p.brightness,
        gamma: p.gamma,
        hue: p.hue - wbShift * 1.8,
      );
    if (p.vignette > 0) {
      command.vignette(start: .38, end: .92, amount: p.vignette);
    }
    command.encodeJpgFile(output.path, quality: 95);
    await command.executeThread();
    if (!await output.exists()) return original;
    return output;
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto || _initializing || _countdown > 0) return;
    setState(() => _takingPhoto = true);
    try {
      if (_timerSeconds > 0) {
        for (var i = _timerSeconds; i > 0; i--) {
          if (!mounted) return;
          setState(() => _countdown = i);
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (mounted) setState(() => _countdown = 0);
      }

      final original = await _capture();
      if (!mounted) return;
      setState(() => _processingPreset = true);
      final rendered = await _renderPreset(original);
      if (!mounted) return;
      setState(() {
        _lastShotPath = rendered.path;
        _processingPreset = false;
      });
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoReviewScreen(
            imagePath: rendered.path,
            presetName: _preset.name,
          ),
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
      if (mounted) {
        setState(() {
          _takingPhoto = false;
          _processingPreset = false;
          _countdown = 0;
        });
      }
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
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 96);
    if (image != null && mounted) {
      setState(() => _lastShotPath = image.path);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoReviewScreen(
            imagePath: image.path,
            presetName: 'Natural',
          ),
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

  void _cycleRatio() {
    setState(() {
      _ratio = _ratio == '4:3' ? '1:1' : _ratio == '1:1' ? '16:9' : '4:3';
    });
  }

  void _cycleTimer() {
    setState(() {
      _timerSeconds = _timerSeconds == 0 ? 3 : _timerSeconds == 3 ? 10 : 0;
    });
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111214),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kamera Ayarları', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Izgara'),
                subtitle: const Text('Üçler kuralı çizgilerini göster.'),
                value: _showGrid,
                onChanged: (v) => setState(() => _showGrid = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.filter_alt_off_outlined),
                title: const Text('Preseti sıfırla'),
                subtitle: const Text('Natural görünümüne dön.'),
                onTap: () {
                  setState(() {
                    _selectedPreset = 0;
                    _wbKelvin = 5200;
                  });
                  Navigator.pop(sheet);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.center_focus_strong_outlined),
                title: const Text('Odağı sıfırla'),
                subtitle: const Text('AF moduna dön.'),
                onTap: () async {
                  await _unlock();
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          child: Text('Kamera başlatılamadı', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topControls(),
            Expanded(child: _preview()),
            _modeStrip(),
            _presetStrip(),
            if (_mode == 'Pro') _proPanel(),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topControls() {
    final flashIcon = _flash == iris.PhotoFlashMode.off
        ? Icons.flash_off_rounded
        : _flash == iris.PhotoFlashMode.auto
            ? Icons.flash_auto_rounded
            : Icons.flash_on_rounded;
    final timerLabel = _timerSeconds == 0 ? 'Kapalı' : '${_timerSeconds} sn';

    return Container(
      height: 78,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(child: _topAction(icon: flashIcon, label: 'Flaş', onTap: _cycleFlash)),
          Expanded(child: _topAction(icon: Icons.crop_rounded, label: _ratio, onTap: _cycleRatio)),
          Expanded(child: _topAction(icon: Icons.timer_outlined, label: timerLabel, onTap: _cycleTimer)),
          Expanded(child: _topAction(icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded, label: 'Izgara', onTap: () => setState(() => _showGrid = !_showGrid))),
          Expanded(child: _topAction(icon: Icons.settings_outlined, label: 'Ayarlar', onTap: _openSettings)),
        ],
      ),
    );
  }

  Widget _topAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 23),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _previewMatrix() {
    final result = List<double>.from(_preset.matrix);
    if (_preset.name == 'Mono') return result;
    final warmth = ((_wbKelvin - 5200) / 3000).clamp(-.8, .8).toDouble();
    result[0] *= 1 + warmth * .10;
    result[6] *= 1 + warmth * .025;
    result[12] *= 1 - warmth * .10;
    return result;
  }

  Widget _preview() {
    return LayoutBuilder(
      builder: (context, outer) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: outer.maxWidth, maxHeight: outer.maxHeight),
            child: AspectRatio(
              aspectRatio: _previewAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(_previewMatrix()),
                      child: LayoutBuilder(
                        builder: (_, constraints) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _tapFocus(d, constraints),
                          onLongPressStart: (d) => _locked ? _unlock() : _longPressLock(d, constraints),
                          child: iris.IrisCameraPreview(
                            aspectRatio: _previewAspectRatio,
                            enableTapToFocus: false,
                            showFocusIndicator: false,
                          ),
                        ),
                      ),
                    ),
                    if (_preset.overlay != Colors.transparent)
                      IgnorePointer(child: ColoredBox(color: _preset.overlay)),
                    if (_showGrid) const IgnorePointer(child: _Grid()),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _glassIcon(Icons.close_rounded, () => Navigator.pop(context)),
                    ),
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
                                border: Border.all(color: const Color(0xFFFFC400), width: 2),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: _locked
                                  ? const Icon(Icons.lock_rounded, color: Color(0xFFFFC400), size: 15)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    if (_locked)
                      Positioned(
                        left: 12,
                        bottom: 54,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .64),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('AF-L', style: TextStyle(color: Color(0xFFFFC400), fontSize: 11, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(child: _zoomPill()),
                    ),
                    if (_countdown > 0)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black38,
                          child: Center(
                            child: Text(
                              '$_countdown',
                              style: const TextStyle(color: Colors.white, fontSize: 86, fontWeight: FontWeight.w300),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glassIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .58),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _zoomPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomButton(.5, '0.5x'),
          _zoomButton(1, '1x'),
          _zoomButton(2, '2x'),
        ],
      ),
    );
  }

  Widget _zoomButton(double value, String label) {
    final selected = (_zoom - value).abs() < .05;
    return GestureDetector(
      onTap: () => _selectZoom(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 54,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF242424) : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFFC400) : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: selected ? 15 : 13,
          ),
        ),
      ),
    );
  }

  Widget _modeStrip() {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: modes.map((mode) {
          final selected = mode == _mode;
          return GestureDetector(
            onTap: () => _selectMode(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: selected ? const Color(0xFFFFC400) : Colors.transparent, width: 2)),
              ),
              child: Text(
                mode,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFC400) : Colors.white60,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _presetStrip() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        itemCount: _presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = _presets[index];
          final selected = index == _selectedPreset;
          return GestureDetector(
            onTap: () => setState(() => _selectedPreset = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 82,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? const Color(0xFFFFC400) : Colors.white12, width: selected ? 2 : 1),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: item.colors),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB8000000)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(top: 13, left: 0, right: 0, child: Icon(Icons.tune_rounded, color: Colors.white70, size: 22)),
                  Positioned(
                    left: 5,
                    right: 5,
                    bottom: 7,
                    child: Text(
                      item.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.05),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _proPanel() {
    return Container(
      height: 118,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _proTab('ISO', '$_iso'),
              _proTab('S', '1/$_shutter'),
              _proTab('WB', '${_wbKelvin}K'),
              _proTab('Odak', _locked ? 'AF-L' : 'AF'),
              _proTab('EV', '${_ev >= 0 ? '+' : ''}${_ev.toStringAsFixed(1)}'),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(child: _activeProEditor()),
        ],
      ),
    );
  }

  Widget _proTab(String key, String value) {
    final selected = _activeProControl == key;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (key == 'Odak') {
            if (_locked) {
              await _unlock();
            } else {
              setState(() => _activeProControl = key);
            }
          } else {
            setState(() => _activeProControl = key);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? const Color(0xFFFFC400) : Colors.transparent, width: 2)),
          ),
          child: Column(
            children: [
              Text(key, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: selected ? const Color(0xFFFFC400) : Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeProEditor() {
    switch (_activeProControl) {
      case 'S':
        final currentIndex = shutterSteps.indexOf(_shutter).clamp(0, shutterSteps.length - 1);
        return _sliderRow(
          minLabel: '1/15',
          maxLabel: '1/2000',
          value: currentIndex.toDouble(),
          min: 0,
          max: (shutterSteps.length - 1).toDouble(),
          divisions: shutterSteps.length - 1,
          onChanged: (v) => setState(() => _shutter = shutterSteps[v.round()]),
        );
      case 'WB':
        return _sliderRow(
          minLabel: '2800K',
          maxLabel: '7500K',
          value: _wbKelvin.toDouble(),
          min: 2800,
          max: 7500,
          divisions: 47,
          onChanged: (v) => setState(() => _wbKelvin = (v / 100).round() * 100),
        );
      case 'Odak':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _unlock,
              icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
              label: const Text('AF'),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: () {
                setState(() => _tip = 'Önizlemede odaklamak istediğin noktaya uzun bas.');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Odak kilidi için önizlemede istediğin noktaya uzun bas.')),
                );
              },
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(_locked ? 'AF-L Aktif' : 'AF-L'),
            ),
          ],
        );
      case 'EV':
        return _sliderRow(
          minLabel: '-0.8',
          maxLabel: '+0.6',
          value: _ev,
          min: -.75,
          max: .55,
          divisions: 13,
          onChanged: (v) {
            setState(() => _ev = v);
            unawaited(_setEv(v));
          },
        );
      default:
        return _sliderRow(
          minLabel: '50',
          maxLabel: '1600',
          value: _iso.toDouble(),
          min: 50,
          max: 1600,
          divisions: 31,
          onChanged: (v) => setState(() => _iso = (v / 50).round() * 50),
        );
    }
  }

  Widget _sliderRow({
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 42, child: Text(minLabel, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 9))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFFC400),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFFFFC400),
              overlayColor: const Color(0x33FFC400),
              trackHeight: 2,
            ),
            child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
        ),
        SizedBox(width: 46, child: Text(maxLabel, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 9))),
      ],
    );
  }

  Widget _bottomBar() {
    return SizedBox(
      height: 108,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: _gallery,
            child: Container(
              width: 54,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF17191C),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white24),
              ),
              child: _lastShotPath == null
                  ? const Icon(Icons.photo_library_outlined, color: Colors.white)
                  : Image.file(File(_lastShotPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.photo_library_outlined, color: Colors.white)),
            ),
          ),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: 82,
              height: 82,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: _takingPhoto
                    ? Padding(
                        padding: const EdgeInsets.all(19),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _processingPreset ? const Color(0xFFFFC400) : Colors.black,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleLens,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF111214), border: Border.all(color: Colors.white24)),
              child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 27),
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: const SizedBox.expand());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .24)
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
