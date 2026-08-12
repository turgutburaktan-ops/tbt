import 'create_post_screen.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iris_camera/iris_camera.dart' as iris;
import 'package:sensors_plus/sensors_plus.dart';

import '../services/ai_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final iris.IrisCamera _camera = iris.IrisCamera();
  final ImagePicker _picker = ImagePicker();
  final iris.FocusIndicatorController _focusIndicatorController =
      iris.FocusIndicatorController();

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
  double _gyroX = 0;
  double _gyroY = 0;

  DateTime? _lastAiAnalysisAt;

  int _currentIso = 100;
  Duration _currentShutter = const Duration(microseconds: 8000); // ~1/125
  double _currentEv = 0.0;
  double _currentZoom = 1.0;
  String _currentFocus = 'AF';
  String _currentWb = 'AUTO';

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
      _lenses = await _camera.listAvailableLenses();

      if (_lenses.isEmpty) {
        if (mounted) {
          setState(() => _initializing = false);
        }
        return;
      }

      await _camera.switchLens(_lenses.first.category);
      await _camera.initialize();

      // Dengeli başlangıç.
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

      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (e) {
      debugPrint('Iris kamera başlatma hatası: $e');
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_lenses.length < 2 || _takingPhoto || _aiBusy) return;

    final next = (_lensIndex + 1) % _lenses.length;

    try {
      await _camera.switchLens(_lenses[next].category);
      _lensIndex = next;

      if (_aiAutoProEnabled) {
        await _applyModeBaseSettings();
        await _analyzeSceneOnce();
      }

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
          builder: (_) => CreatePostScreen(
            initialImagePath: image.path,
          ),
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

    final denominator = max(1, (1000000 / us).round());
    return '1/$denominator';
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
    String focus;
    String wb;

    switch (_selectedMode) {
      case 'Portre':
        iso = 100;
        shutter = _durationForDenominator(160);
        ev = 0.15;
        zoom = 1.4;
        focus = _subjectLocked ? 'AF-L' : 'AF';
        wb = 'AUTO';
        break;

      case 'Gece':
        iso = 800;
        shutter = _durationForDenominator(30);
        ev = 0.35;
        zoom = 1.0;
        focus = _subjectLocked ? 'AF-L' : 'AF';
        wb = 'AUTO';
        break;

      case 'Sinematik':
        iso = 100;
        shutter = _durationForDenominator(50);
        ev = -0.10;
        zoom = 1.1;
        focus = _subjectLocked ? 'AF-L' : 'AF';
        wb = 'AUTO';
        break;

      case 'Astro':
        iso = 800;
        shutter = const Duration(milliseconds: 500);
        ev = 0.30;
        zoom = 1.0;
        focus = _subjectLocked ? 'AF-L' : 'AF';
        wb = 'AUTO';
        break;

      case 'Pro':
        iso = 100;
        shutter = _durationForDenominator(125);
        ev = 0.0;
        zoom = 1.0;
        focus = _subjectLocked ? 'AF-L' : 'AF';
        wb = 'AUTO';
        break;

      case 'Fotoğraf':
      default:
        iso = 100;
        shutter = _durationForDenominator(125);
        ev = 0.0;
        zoom = 1.0;
        focus = _subjectLocked ? 'AF-L' : 'AF';
        wb = 'AUTO';
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
        await _camera.setFocus(point: _subjectPoint);
      } catch (_) {}

      try {
        await _camera.setExposurePoint(_subjectPoint);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentZoom = zoom;
        _currentFocus = focus;
        _currentWb = wb;
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

    final lowLight =
        combined.contains('karanlık') ||
        combined.contains('az ışık') ||
        combined.contains('ışık düşük') ||
        combined.contains('düşük ışık');

    final veryLowLight =
        combined.contains('çok karanlık') ||
        combined.contains('çok düşük ışık');

    final tooBright =
        combined.contains('fazla parlak') ||
        combined.contains('çok parlak') ||
        combined.contains('aşırı ışık') ||
        combined.contains('ışığı azalt');

    final subjectPriority =
        _subjectLocked ||
        combined.contains('kişi') ||
        combined.contains('insan') ||
        combined.contains('yüz') ||
        combined.contains('portre');

    if (lowLight) {
      iso = min(1600, max(iso, 400));
      ev += 0.20;

      if (subjectPriority || _movementLevel > 0.8) {
        // Kişiyi/elde çekimi dondur: daha hızlı shutter, ISO daha yüksek.
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

    if (_selectedMode == 'Portre') {
      if (subjectPriority) {
        shutter = _durationForDenominator(160);
        iso = lowLight ? max(iso, 400) : 100;
      }
    }

    if (_selectedMode == 'Sinematik') {
      // Fotoğraf yakalamada da 180° shutter karakterine yakın 1/50.
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

    // Canlı önizlemede AF/AE gerçek olarak uygulanır.
    try {
      if (_subjectLocked && _subjectPoint != null) {
        await _camera.setFocus(point: _subjectPoint);
        await _camera.setExposurePoint(_subjectPoint);
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

  iris.PhotoCaptureOptions _captureOptions() {
    return iris.PhotoCaptureOptions(
      flashMode: iris.PhotoFlashMode.auto,
      iso: _currentIso,
      exposureDuration: _currentShutter,
    );
  }

  Future<File> _captureToTempFile({
    bool useProOverrides = true,
  }) async {
    final bytes = await _camera.capturePhoto(
      options: useProOverrides
          ? _captureOptions()
          : const iris.PhotoCaptureOptions(
              flashMode: iris.PhotoFlashMode.auto,
            ),
    );

    final path =
        '${Directory.systemTemp.path}/tbt_${DateTime.now().microsecondsSinceEpoch}.jpg';

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto || _aiBusy) return;

    _takingPhoto = true;

    try {
      final file = await _captureToTempFile(
        useProOverrides: _aiAutoProEnabled,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePostScreen(
            initialImagePath: file.path,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Iris fotoğraf çekme hatası: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf çekilemedi.'),
          ),
        );
      }
    } finally {
      _takingPhoto = false;
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

    if (next) {
      await _applyModeBaseSettings();
      await _analyzeSceneOnce();
    }
  }

  Future<void> _analyzeSceneOnce() async {
    if (!_aiAutoProEnabled || _aiBusy || _takingPhoto) return;

    if (mounted) {
      setState(() {
        _aiBusy = true;
        _aiStatus = 'adjust';
        _aiMainTip = 'Sahne analiz ediliyor...';
      });
    }

    File? temp;

    try {
      // Analiz karesi için override zorlamıyoruz; sahnenin doğal halini AI görsün.
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

      if (mounted) {
        setState(() => _aiBusy = false);
      } else {
        _aiBusy = false;
      }
    }
  }

  String get _subjectModeLabel {
    if (!_subjectLocked || _subjectPoint == null) {
      return _selectedMode;
    }

    final x = (_subjectPoint!.dx * 100).round();
    final y = (_subjectPoint!.dy * 100).round();

    return '$_selectedMode | ANA ÖZNE kilitli: x=$x%, y=$y%. '
        'Kalabalıktaki diğer kişileri ana özne kabul etme.';
  }

  Future<void> _handlePreviewTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    if (_subjectLocked) {
      await _clearSubjectLock();
      return;
    }

    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;

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

  void _scheduleSceneReanalysis() {
    if (!_aiAutoProEnabled || _aiBusy || _takingPhoto) return;

    final last = _lastAiAnalysisAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 4)) {
      return;
    }

    _sceneChangeTimer?.cancel();
    _sceneChangeTimer = Timer(
      const Duration(milliseconds: 900),
      () {
        if (mounted && _aiAutoProEnabled && !_aiBusy) {
          _analyzeSceneOnce();
        }
      },
    );
  }

  void _startMotionAssistant() {
    _accelerometerSubscription =
        accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x +
            event.y * event.y +
            event.z * event.z,
      );

      final movement = (magnitude - 9.81).abs();

      if (!mounted) return;

      if ((_movementLevel - movement).abs() > 0.15) {
        setState(() => _movementLevel = movement);
      }
    });

    _gyroscopeSubscription =
        gyroscopeEventStream().listen((event) {
      if (!mounted) return;

      _gyroX = event.x;
      _gyroY = event.y;

      if (_aiAutoProEnabled &&
          (event.x.abs() > 0.9 ||
              event.y.abs() > 0.9 ||
              event.z.abs() > 0.9)) {
        _scheduleSceneReanalysis();
      }
    });
  }

  Future<void> _selectMode(String mode) async {
    if (mode == _selectedMode) return;

    _sceneChangeTimer?.cancel();

    setState(() {
      _selectedMode = mode;

      if (_aiAutoProEnabled) {
        _aiStatus = 'adjust';
        _aiMainTip = 'Yeni moda göre analiz ediliyor...';
      }
    });

    await _applyModeBaseSettings();

    if (_aiAutoProEnabled) {
      await _analyzeSceneOnce();
    }
  }

  void _toggleSpotMode() {
    setState(() => _spotModeEnabled = !_spotModeEnabled);

    if (_aiAutoProEnabled) {
      _analyzeSceneOnce();
    }
  }

  String get _lightHudText {
    if (_aiBusy) return 'IŞIK\nANALİZ';

    final text = _aiLightTip.toLowerCase();

    if (text.contains('karanlık') ||
        text.contains('az ışık') ||
        text.contains('düşük')) {
      return 'IŞIK\nDÜZELTİLDİ';
    }

    if (text.contains('parlak') ||
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

    return _spotModeEnabled
        ? 'MEKAN\nDENGELİ'
        : 'SAHNE\nDENGELİ';
  }

  String get _isoHud => _currentIso.toString();

  String get _wbHud {
    // iris_camera Android tarafında WB'yi auto/lock düzeyinde destekler.
    // Kelvin override Android'de sunulmuyor.
    return _currentWb;
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
        body: Center(
          child: CircularProgressIndicator(),
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
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Kamera başlatılamadı.',
                    style: TextStyle(
                      color: Colors.white,
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
        child: Stack(
          children: [
            Positioned(
              top: 70,
              left: 8,
              right: 8,
              bottom: 218,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _handlePreviewTap(
                          details,
                          constraints,
                        );
                      },
                      child: const iris.IrisCameraPreview(
                        aspectRatio: 3 / 4,
                        enableTapToFocus: false,
                        showFocusIndicator: false,
                      ),
                    );
                  },
                ),
              ),
            ),

            if (_showGrid)
              const Positioned(
                top: 70,
                left: 8,
                right: 8,
                bottom: 218,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(
                    Radius.circular(24),
                  ),
                  child: IgnorePointer(
                    child: _CameraGrid(),
                  ),
                ),
              ),

            if (_subjectLocked && _subjectPoint != null)
              Positioned(
                top: 70,
                left: 8,
                right: 8,
                bottom: 218,
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final point = Offset(
                        _subjectPoint!.dx * constraints.maxWidth,
                        _subjectPoint!.dy * constraints.maxHeight,
                      );

                      return Stack(
                        children: [
                          Positioned(
                            left: point.dx - 32,
                            top: point.dy - 32,
                            child: Container(
                              width: 64,
                              height: 64,
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
                                    size: 15,
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
              ),

            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _toggleAiAutoPro,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _aiAutoProEnabled
                            ? const Color(0xFFFFC107)
                            : Colors.black.withOpacity(.68),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _aiAutoProEnabled
                              ? const Color(0xFFFFC107)
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: _aiAutoProEnabled
                                ? Colors.black
                                : Colors.white,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _aiAutoProEnabled
                                ? 'AI AUTO PRO  AÇIK'
                                : 'AI AUTO PRO',
                            style: TextStyle(
                              color: _aiAutoProEnabled
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _CircleButton(
                    icon: _showGrid ? Icons.grid_on : Icons.grid_off,
                    onTap: () {
                      setState(() => _showGrid = !_showGrid);
                    },
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(
                    icon: _spotModeEnabled
                        ? Icons.location_on
                        : Icons.location_on_outlined,
                    onTap: _toggleSpotMode,
                  ),
                ],
              ),
            ),

            if (_aiAutoProEnabled)
              Positioned(
                top: 88,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 330),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.62),
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _aiBusy
                                ? 'Sahne analiz ediliyor...'
                                : _aiMainTip,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
                top: 170,
                right: 18,
                child: Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.66),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white12,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.center_focus_strong,
                        color: Colors.white,
                        size: 21,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _currentFocus,
                        style: const TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 9),
                        child: Divider(
                          height: 1,
                          color: Colors.white12,
                        ),
                      ),
                      const Icon(
                        Icons.landscape_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _compositionHudText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 9),
                        child: Divider(
                          height: 1,
                          color: Colors.white12,
                        ),
                      ),
                      const Icon(
                        Icons.light_mode_outlined,
                        color: Color(0xFFFFC107),
                        size: 21,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _lightHudText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 218,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF050608),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                ),
              ),
            ),

            if (_aiAutoProEnabled)
              Positioned(
                left: 18,
                right: 18,
                bottom: 220,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.72),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Param(
                        label: 'ISO',
                        value: _isoHud,
                      ),
                      _Param(
                        label: 'S',
                        value: _shutterHud,
                      ),
                      _Param(
                        label: 'ODAK',
                        value: _currentFocus,
                      ),
                      _Param(
                        label: 'WB',
                        value: _wbHud,
                      ),
                      _Param(
                        label: 'EV',
                        value:
                            '${_currentEv >= 0 ? '+' : ''}${_currentEv.toStringAsFixed(1)}',
                        accent: true,
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 155,
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _modes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final mode = _modes[index];
                    final selected = mode == _selectedMode;

                    return GestureDetector(
                      onTap: () => _selectMode(mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFFC107)
                              : Colors.black.withOpacity(.62),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            mode,
                            style: TextStyle(
                              color:
                                  selected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              left: 25,
              right: 25,
              bottom: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.photo_library_outlined,
                    size: 56,
                    onTap: _pickFromGallery,
                  ),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 86,
                      height: 86,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFC107),
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
            color: accent
                ? const Color(0xFFFFC107)
                : Colors.white,
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
  final VoidCallback onTap;
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
          color: Colors.black.withOpacity(.68),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * .48,
        ),
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
      ..color = Colors.white.withOpacity(.30)
      ..strokeWidth = 1;

    final x1 = size.width / 3;
    final x2 = size.width * 2 / 3;
    final y1 = size.height / 3;
    final y2 = size.height * 2 / 3;

    canvas.drawLine(
      Offset(x1, 0),
      Offset(x1, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(x2, 0),
      Offset(x2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, y1),
      Offset(size.width, y1),
      paint,
    );
    canvas.drawLine(
      Offset(0, y2),
      Offset(size.width, y2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
