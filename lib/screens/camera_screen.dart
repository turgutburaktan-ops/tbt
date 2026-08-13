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

class _CameraScreenState extends State<CameraScreen> {
  final iris.IrisCamera _camera = iris.IrisCamera();
  final ImagePicker _picker = ImagePicker();

  List<iris.CameraLensDescriptor> _lenses = [];
  int _lensIndex = 0;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Timer? _sceneChangeTimer;

  bool _initializing = true;
  bool _takingPhoto = false;
  bool _aiBusy = false;
  bool _aiAutoProEnabled = false;
  bool _showGrid = true;
  bool _spotModeEnabled = false;
  bool _subjectLocked = false;
  Offset? _subjectPoint;

  String _selectedMode = 'Fotoğraf';
  String _aiStatus = 'idle';
  String _aiMainTip = 'AI AUTO PRO kapalı.';
  String _aiCompositionTip = '';
  String _aiLightTip = '';
  String _aiSubjectTip = '';

  double _movementLevel = 0;
  DateTime? _lastAiAnalysisAt;

  int _currentIso = 100;
  Duration _currentShutter = const Duration(microseconds: 8000);
  double _currentEv = 0.0;
  double _currentZoom = 1.0;
  String _currentFocus = 'AF';
  String _currentWb = 'AUTO';

  iris.PhotoFlashMode _flashMode = iris.PhotoFlashMode.off;

  final List<String> _modes = const [
    'Fotoğraf',
    'Portre',
    'Gece',
    'Sinematik',
    'Astro',
    'Pro',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startMotionAssistant();
  }

  Future<void> _initializeCamera() async {
    try {
      final lenses = await _camera.listAvailableLenses();
      if (lenses.isEmpty) {
        if (mounted) {
          setState(() {
            _lenses = [];
            _initializing = false;
          });
        }
        return;
      }

      _lenses = lenses;
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

      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      debugPrint('Iris kamera başlatma hatası: $e');
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (_lenses.length < 2 || _takingPhoto || _aiBusy) return;

    final next = (_lensIndex + 1) % _lenses.length;
    try {
      await _camera.switchLens(_lenses[next].category);
      _lensIndex = next;
      await _applyModeBaseSettings();
      if (_aiAutoProEnabled) await _analyzeSceneOnce();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Lens değiştirme hatası: $e');
    }
  }

  Future<void> _pickFromGallery() async {
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

  Duration _durationForDenominator(int denominator) {
    if (denominator <= 0) return const Duration(milliseconds: 8);
    return Duration(
      microseconds: max(1, (1000000 / denominator).round()),
    );
  }

  String get _shutterHud {
    final us = _currentShutter.inMicroseconds;
    if (us >= 1000000) {
      return '${(us / 1000000).toStringAsFixed(1)}s';
    }
    return '1/${max(1, (1000000 / us).round())}';
  }

  String get _flashLabel {
    switch (_flashMode) {
      case iris.PhotoFlashMode.on:
        return 'AÇIK';
      case iris.PhotoFlashMode.auto:
        return 'AUTO';
      case iris.PhotoFlashMode.off:
        return 'KAPALI';
    }
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case iris.PhotoFlashMode.on:
        return Icons.flash_on_rounded;
      case iris.PhotoFlashMode.auto:
        return Icons.flash_auto_rounded;
      case iris.PhotoFlashMode.off:
        return Icons.flash_off_rounded;
    }
  }

  void _cycleFlash() {
    setState(() {
      switch (_flashMode) {
        case iris.PhotoFlashMode.off:
          _flashMode = iris.PhotoFlashMode.auto;
          break;
        case iris.PhotoFlashMode.auto:
          _flashMode = iris.PhotoFlashMode.on;
          break;
        case iris.PhotoFlashMode.on:
          _flashMode = iris.PhotoFlashMode.off;
          break;
      }
    });
  }

  Future<Duration> _clampExposureDuration(Duration requested) async {
    try {
      final maxDuration = await _camera.getMaxExposureDuration();
      if (requested > maxDuration) return maxDuration;
    } catch (_) {}
    return requested;
  }

  Future<void> _applyModeBaseSettings() async {
    int iso;
    Duration shutter;
    double ev;
    double zoom;

    switch (_selectedMode) {
      case 'Portre':
        iso = 100;
        shutter = _durationForDenominator(160);
        ev = 0.15;
        zoom = 1.4;
        break;
      case 'Gece':
        iso = 800;
        shutter = _durationForDenominator(30);
        ev = 0.35;
        zoom = 1.0;
        break;
      case 'Sinematik':
        iso = 100;
        shutter = _durationForDenominator(50);
        ev = -0.10;
        zoom = 1.1;
        break;
      case 'Astro':
        iso = 800;
        shutter = const Duration(milliseconds: 500);
        ev = 0.30;
        zoom = 1.0;
        break;
      case 'Pro':
      case 'Fotoğraf':
      default:
        iso = 100;
        shutter = _durationForDenominator(125);
        ev = 0.0;
        zoom = 1.0;
        break;
    }

    shutter = await _clampExposureDuration(shutter);

    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
    } catch (_) {}
    try {
      await _camera.setFocusMode(
        _subjectLocked ? iris.FocusMode.locked : iris.FocusMode.auto,
      );
    } catch (_) {}
    try {
      await _camera.setExposureOffset(ev);
    } catch (_) {}
    try {
      await _camera.setZoom(zoom);
    } catch (_) {}

    if (_subjectLocked && _subjectPoint != null) {
      try {
        await _camera.setFocus(point: _subjectPoint!);
        await _camera.setExposurePoint(_subjectPoint!);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentZoom = zoom;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
        _currentWb = 'AUTO';
      });
    }
  }

  Future<void> _applyAiDecision() async {
    final combined = [
      _aiMainTip,
      _aiLightTip,
      _aiCompositionTip,
      _aiSubjectTip,
    ].join(' ').toLowerCase();

    var iso = _currentIso;
    var shutter = _currentShutter;
    var ev = _currentEv;

    final lowLight = combined.contains('karanlık') ||
        combined.contains('az ışık') ||
        combined.contains('ışık düşük') ||
        combined.contains('düşük ışık');
    final veryLowLight = combined.contains('çok karanlık') ||
        combined.contains('çok düşük ışık');
    final tooBright = combined.contains('fazla parlak') ||
        combined.contains('çok parlak') ||
        combined.contains('aşırı ışık') ||
        combined.contains('ışığı azalt');
    final subjectPriority = _subjectLocked ||
        combined.contains('kişi') ||
        combined.contains('insan') ||
        combined.contains('yüz') ||
        combined.contains('portre');

    if (lowLight) {
      iso = min(1600, max(iso, 400));
      ev += 0.20;
      if (subjectPriority || _movementLevel > 0.8) {
        iso = min(1600, max(iso, 800));
        shutter = _durationForDenominator(60);
      } else {
        shutter = _durationForDenominator(30);
      }
    }

    if (veryLowLight) {
      if (_selectedMode == 'Astro' && _movementLevel < 0.8) {
        iso = 800;
        shutter = const Duration(milliseconds: 750);
      } else {
        iso = 1600;
        shutter = _durationForDenominator(50);
      }
      ev += 0.15;
    }

    if (tooBright) {
      iso = 100;
      shutter = _durationForDenominator(250);
      ev -= 0.30;
    }

    if (_selectedMode == 'Portre' && subjectPriority) {
      shutter = _durationForDenominator(160);
      iso = lowLight ? max(iso, 400) : 100;
    }

    if (_selectedMode == 'Sinematik') {
      shutter = _durationForDenominator(50);
      iso = lowLight ? max(iso, 400) : 100;
    }

    if (_selectedMode == 'Gece') {
      iso = max(iso, 800);
      if (!subjectPriority && _movementLevel < 0.8) {
        shutter = _durationForDenominator(25);
      }
    }

    if (_selectedMode == 'Astro') {
      iso = max(iso, 800);
      if (_movementLevel < 0.8) {
        shutter = const Duration(milliseconds: 750);
      }
    }

    shutter = await _clampExposureDuration(shutter);

    double minEv = -2.0;
    double maxEv = 2.0;
    try {
      minEv = await _camera.getMinExposureOffset();
      maxEv = await _camera.getMaxExposureOffset();
    } catch (_) {}
    ev = ev.clamp(minEv, maxEv).toDouble();

    try {
      await _camera.setExposureOffset(ev);
    } catch (_) {}

    try {
      if (_subjectLocked && _subjectPoint != null) {
        await _camera.setFocus(point: _subjectPoint!);
        await _camera.setExposurePoint(_subjectPoint!);
        await _camera.setFocusMode(iris.FocusMode.locked);
      } else {
        await _camera.setFocusMode(iris.FocusMode.auto);
        await _camera.setFocus(point: const Offset(0.5, 0.5));
        await _camera.setExposurePoint(const Offset(0.5, 0.5));
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
      });
    }
  }

  Future<File> _captureToTempFile({required bool useProOverrides}) async {
    final options = useProOverrides
        ? iris.PhotoCaptureOptions(
            flashMode: _flashMode,
            iso: _currentIso.toDouble(),
            exposureDuration: _currentShutter,
          )
        : const iris.PhotoCaptureOptions(
            flashMode: iris.PhotoFlashMode.off,
          );

    final bytes = await _camera.capturePhoto(options: options);
    if (bytes.isEmpty) {
      throw Exception('IrisCamera boş fotoğraf verisi döndürdü.');
    }

    final file = File(
      '${Directory.systemTemp.path}/tbt_iris_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Fotoğraf dosyası oluşturulamadı.');
    }
    return file;
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto || _aiBusy || _initializing) return;
    setState(() => _takingPhoto = true);

    try {
      if (_aiAutoProEnabled) {
        await _applyAiDecision();
      }

      final file = await _captureToTempFile(
        useProOverrides: _aiAutoProEnabled,
      );

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
            content: Text(
              'Fotoğraf çekilemedi. Kamera oturumunu kapatıp yeniden açmayı dene.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _toggleAiAutoPro() async {
    final next = !_aiAutoProEnabled;
    _sceneChangeTimer?.cancel();

    setState(() {
      _aiAutoProEnabled = next;
      if (next) {
        _aiStatus = 'adjust';
        _aiMainTip = 'Sahne analiz ediliyor...';
      } else {
        _aiStatus = 'idle';
        _aiMainTip = 'AI AUTO PRO kapalı.';
        _aiCompositionTip = '';
        _aiLightTip = '';
        _aiSubjectTip = '';
      }
    });

    await _applyModeBaseSettings();
    if (next) await _analyzeSceneOnce();
  }

  Future<void> _analyzeSceneOnce() async {
    if (!_aiAutoProEnabled || _aiBusy || _takingPhoto) return;

    setState(() {
      _aiBusy = true;
      _aiStatus = 'adjust';
      _aiMainTip = 'Sahne analiz ediliyor...';
    });

    File? temp;
    try {
      temp = await _captureToTempFile(useProOverrides: false);
      final analysis = await AiService.analyzeLiveFrame(
        imagePath: temp.path,
        mode: _subjectModeLabel,
      );
      if (!mounted) return;

      setState(() {
        _aiStatus = analysis.status;
        _aiMainTip = analysis.mainTip;
        _aiCompositionTip = analysis.compositionTip;
        _aiLightTip = analysis.lightTip;
        _aiSubjectTip = analysis.subjectTip;
      });

      await _applyAiDecision();
      _lastAiAnalysisAt = DateTime.now();
    } catch (e) {
      debugPrint('AI analiz hatası: $e');
      if (mounted) {
        setState(() {
          _aiStatus = 'warning';
          _aiMainTip = 'AI bağlantısı kurulamadı.';
        });
      }
    } finally {
      if (temp != null) {
        try {
          if (await temp.exists()) await temp.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  String get _subjectModeLabel {
    if (!_subjectLocked || _subjectPoint == null) return _selectedMode;
    final x = (_subjectPoint!.dx * 100).round();
    final y = (_subjectPoint!.dy * 100).round();
    return '$_selectedMode | ANA ÖZNE kilitli: x=$x%, y=$y%. '
        'Kalabalıktaki diğer kişileri ana özne kabul etme.';
  }

  Future<void> _handlePreviewTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;

    if (_subjectLocked) {
      await _clearSubjectLock();
      return;
    }

    final normalized = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );

    setState(() {
      _subjectLocked = true;
      _subjectPoint = normalized;
      _currentFocus = 'AF-L';
    });

    try {
      await _camera.setFocus(point: normalized);
      await _camera.setExposurePoint(normalized);
      await _camera.setFocusMode(iris.FocusMode.locked);
    } catch (e) {
      debugPrint('Ana özne odak hatası: $e');
    }
  }

  Future<void> _clearSubjectLock() async {
    setState(() {
      _subjectLocked = false;
      _subjectPoint = null;
      _currentFocus = 'AF';
    });

    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: const Offset(0.5, 0.5));
      await _camera.setExposurePoint(const Offset(0.5, 0.5));
    } catch (_) {}
  }

  Future<void> _selectMode(String mode) async {
    if (mode == _selectedMode || _takingPhoto || _aiBusy) return;

    _sceneChangeTimer?.cancel();
    setState(() {
      _selectedMode = mode;
      if (_aiAutoProEnabled) {
        _aiStatus = 'adjust';
        _aiMainTip = 'Yeni moda göre analiz ediliyor...';
      }
    });

    await _applyModeBaseSettings();
    if (_aiAutoProEnabled) await _analyzeSceneOnce();
  }

  void _toggleSpotMode() {
    setState(() => _spotModeEnabled = !_spotModeEnabled);
    if (_aiAutoProEnabled) _analyzeSceneOnce();
  }

  void _scheduleSceneReanalysis() {
    if (!_aiAutoProEnabled || _aiBusy || _takingPhoto) return;
    final last = _lastAiAnalysisAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 4)) {
      return;
    }

    _sceneChangeTimer?.cancel();
    _sceneChangeTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && _aiAutoProEnabled && !_aiBusy && !_takingPhoto) {
        _analyzeSceneOnce();
      }
    });
  }

  void _startMotionAssistant() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final movement = (magnitude - 9.81).abs();
      if (mounted && (_movementLevel - movement).abs() > 0.15) {
        setState(() => _movementLevel = movement);
      }
    });

    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      if (!mounted || !_aiAutoProEnabled) return;
      if (event.x.abs() > 0.9 ||
          event.y.abs() > 0.9 ||
          event.z.abs() > 0.9) {
        _scheduleSceneReanalysis();
      }
    });
  }

  String get _lightHudText {
    if (_aiBusy) return 'IŞIK\nANALİZ';
    final text = _aiLightTip.toLowerCase();
    if (text.contains('karanlık') ||
        text.contains('az ışık') ||
        text.contains('düşük') ||
        text.contains('parlak') ||
        text.contains('fazla')) {
      return 'IŞIK\nDÜZELTİLDİ';
    }
    if (_aiStatus == 'good') return 'IŞIK\nİYİ';
    return 'IŞIK\nDENGELİ';
  }

  String get _compositionHudText {
    if (_subjectLocked) return 'ÖZNE\nKİLİTLİ';
    final text = _aiCompositionTip.toLowerCase();
    if (text.contains('sol')) return 'KADRAJ\nSOLA';
    if (text.contains('sağ')) return 'KADRAJ\nSAĞA';
    return _spotModeEnabled ? 'MEKAN\nDENGELİ' : 'SAHNE\nDENGELİ';
  }

  @override
  void dispose() {
    _sceneChangeTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _camera.disposeSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_lenses.isEmpty) {
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
              const Expanded(
                child: Center(
                  child: Text(
                    'Kamera başlatılamadı.',
                    style: TextStyle(color: Colors.white),
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
            _buildTopBar(),
            Expanded(child: _buildPreview()),
            if (_aiAutoProEnabled) _buildCameraParams(),
            _buildModes(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            _CircleButton(
              icon: Icons.close,
              size: 42,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: GestureDetector(
                onTap: _aiBusy || _takingPhoto ? null : _toggleAiAutoPro,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _aiAutoProEnabled
                        ? const Color(0xFFFFC107)
                        : const Color(0xFF151A22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 17,
                        color: _aiAutoProEnabled ? Colors.black : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _aiAutoProEnabled ? 'AI AUTO PRO' : 'AI AUTO PRO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                _aiAutoProEnabled ? Colors.black : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            _CircleButton(
              icon: _flashIcon,
              size: 42,
              onTap: _cycleFlash,
            ),
            const SizedBox(width: 6),
            _CircleButton(
              icon: _showGrid ? Icons.grid_on : Icons.grid_off,
              size: 42,
              onTap: () => setState(() => _showGrid = !_showGrid),
            ),
            const SizedBox(width: 6),
            _CircleButton(
              icon: _spotModeEnabled
                  ? Icons.location_on
                  : Icons.location_on_outlined,
              size: 42,
              onTap: _toggleSpotMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _handlePreviewTap(details, constraints),
                  child: const iris.IrisCameraPreview(
                    enableTapToFocus: false,
                    showFocusIndicator: false,
                  ),
                );
              },
            ),
            if (_showGrid)
              const IgnorePointer(child: _CameraGrid()),
            if (_subjectLocked && _subjectPoint != null)
              IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final point = Offset(
                      _subjectPoint!.dx * constraints.maxWidth,
                      _subjectPoint!.dy * constraints.maxHeight,
                    );
                    return Stack(
                      children: [
                        Positioned(
                          left: point.dx - 30,
                          top: point.dy - 30,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFFFC107),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: Color(0xFFFFC107),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (_aiAutoProEnabled)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.68),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_aiBusy)
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFC107),
                            ),
                          )
                        else
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Color(0xFFFFC107),
                          ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            _aiBusy ? 'Sahne analiz ediliyor...' : _aiMainTip,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_aiAutoProEnabled)
              Positioned(
                right: 10,
                top: 70,
                child: Container(
                  width: 70,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.66),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.center_focus_strong,
                          color: Colors.white, size: 19),
                      const SizedBox(height: 3),
                      Text(
                        _currentFocus,
                        style: const TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${_currentZoom.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 8.5,
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      Text(
                        _compositionHudText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      Text(
                        _lightHudText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraParams() {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF11151C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Param(label: 'ISO', value: '$_currentIso'),
          _Param(label: 'S', value: _shutterHud),
          _Param(label: 'ODAK', value: _currentFocus),
          _Param(label: 'WB', value: _currentWb),
          _Param(
            label: 'EV',
            value:
                '${_currentEv >= 0 ? '+' : ''}${_currentEv.toStringAsFixed(1)}',
            accent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildModes() {
    return Container(
      color: const Color(0xFF050608),
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final mode = _modes[index];
          final selected = mode == _selectedMode;
          return GestureDetector(
            onTap: () => _selectMode(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFC107)
                    : const Color(0xFF151A22),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(
                mode,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      height: 112,
      color: const Color(0xFF050608),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(
            icon: Icons.photo_library_outlined,
            size: 54,
            onTap: _pickFromGallery,
          ),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: 82,
              height: 82,
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
                        padding: EdgeInsets.all(19),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleButton(
                icon: Icons.cameraswitch_outlined,
                size: 54,
                onTap: _toggleCamera,
              ),
              const SizedBox(height: 3),
              Text(
                'Flaş $_flashLabel',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Param extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _Param({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: accent ? const Color(0xFFFFC107) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
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
          color: const Color(0xFF151A22),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: size * .46),
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
