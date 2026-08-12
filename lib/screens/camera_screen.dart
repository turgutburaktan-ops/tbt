import 'create_post_screen.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/ai_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  final ImagePicker _picker = ImagePicker();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  Timer? _liveAiTimer;
  Timer? _autoCaptureTimer;

  int _cameraIndex = 0;

  bool _initializing = true;
  bool _flashEnabled = false;
  bool _showGrid = true;
  bool _showAssistant = true;

  bool _liveAiEnabled = false;
  bool _liveAiBusy = false;
  bool _aiAutoProEnabled = false;

  bool _subjectLocked = false;
  Offset? _subjectPoint;
  bool _spotModeEnabled = false;

  String _cinematicGuide = '';
  String _stabilityGuide = '';

  double _currentZoom = 1.0;
  double _currentExposure = 0.0;

  bool _autoCaptureEnabled = false;
  bool _autoCaptureCountdown = false;

  bool _takingUserPhoto = false;

  String _selectedFilter = 'Fotoğraf';

  String _aiStatus = 'idle';

  String _aiMainTip =
      'Canlı AI kapalı. Açmak için anahtarı kullan.';

  String _aiCompositionTip = '';
  String _aiLightTip = '';
  String _aiSubjectTip = '';

  String _movementTip = '✓ Telefon yeterince sabit.';
  String _levelTip = '✓ Kadraj dengeli.';

  double _movementLevel = 0;
  double _gyroX = 0;
  double _gyroY = 0;

  int _countdown = 2;

  final List<String> _filters = const [
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

  // =====================================================
  // CAMERA
  // =====================================================

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
          });
        }

        return;
      }

      await _startCamera(0);
    } catch (e) {
      debugPrint('Kamera başlatma hatası: $e');

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _startCamera(int index) async {
    if (_cameras.isEmpty) {
      return;
    }

    _liveAiTimer?.cancel();
    _cancelAutoCapture();

    await _controller?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      _controller = controller;
      _cameraIndex = index;

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }

      if (_liveAiEnabled) {
        _startLiveAiTimer();
      }
    } catch (e) {
      debugPrint('Kamera başlatılamadı: $e');

      await controller.dispose();

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 ||
        _liveAiBusy ||
        _takingUserPhoto ||
        _autoCaptureCountdown) {
      return;
    }

    final nextIndex =
        (_cameraIndex + 1) % _cameras.length;

    await _startCamera(nextIndex);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _liveAiBusy) {
      return;
    }

    try {
      _flashEnabled = !_flashEnabled;

      await controller.setFlashMode(
        _flashEnabled
            ? FlashMode.torch
            : FlashMode.off,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Flaş hatası: $e');
    }
  }

  // =====================================================
  // MANUEL FOTOĞRAF
  // =====================================================

 Future<void> _takePhoto() async {
  final controller = _controller;

  if (controller == null ||
      !controller.value.isInitialized ||
      controller.value.isTakingPicture ||
      _liveAiBusy ||
      _takingUserPhoto) {
    return;
  }

  _takingUserPhoto = true;

  _cancelAutoCapture();

  try {
    final image = await controller.takePicture();

    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          initialImagePath: image.path,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Fotoğraf çekme hatası: $e');
  } finally {
    _takingUserPhoto = false;
  }
}

  // =====================================================
  // GALERİ
  // =====================================================

  Future<void> _pickFromGallery() async {
  try {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
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

  // =====================================================
  // CANLI AI
  // =====================================================

  void _toggleLiveAi() {
    _cancelAutoCapture();

    setState(() {
      _liveAiEnabled =
          !_liveAiEnabled;

      if (_liveAiEnabled) {
        _aiStatus = 'adjust';

        _aiMainTip =
            'Kadraj inceleniyor...';
      } else {
        _aiStatus = 'idle';

        _aiMainTip =
            'Canlı AI kapalı.';

        _aiCompositionTip = '';
        _aiLightTip = '';
        _aiSubjectTip = '';
      }
    });

    if (_liveAiEnabled) {
      _startLiveAiTimer();

      _captureAndAnalyzeLiveFrame();
    } else {
      _liveAiTimer?.cancel();
    }
  }

  void _startLiveAiTimer() {
    _liveAiTimer?.cancel();

    _liveAiTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        _captureAndAnalyzeLiveFrame();
      },
    );
  }

  Future<void>
      _captureAndAnalyzeLiveFrame() async {
    final controller = _controller;

    if (!_liveAiEnabled ||
        _liveAiBusy ||
        _takingUserPhoto ||
        _autoCaptureCountdown ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    if (mounted) {
      setState(() {
        _liveAiBusy = true;
      });
    }

    String? temporaryPath;

    try {
      final frame =
          await controller.takePicture();

      temporaryPath = frame.path;

      final analysis =
          await AiService
              .analyzeLiveFrame(
        imagePath: frame.path,
        mode: _subjectModeLabel,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _aiStatus =
            analysis.status;

        _aiMainTip =
            analysis.mainTip;

        _aiCompositionTip =
            analysis.compositionTip;

        _aiLightTip =
            analysis.lightTip;

        _aiSubjectTip =
            analysis.subjectTip;
      });

      if (_aiAutoProEnabled) {
        await _applyAutoProCameraSettings();
        await _applyAiDrivenAdjustments();
      }
    } catch (e) {
      debugPrint(
        'Canlı AI hatası: $e',
      );

      if (mounted) {
        setState(() {
          _aiStatus = 'warning';

          _aiMainTip =
              'AI bağlantısı bekleniyor...';
        });
      }
    } finally {
      if (temporaryPath != null) {
        try {
          final file =
              File(temporaryPath);

          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _liveAiBusy = false;
        });

        // ÖNEMLİ:
        // AI isteği tamamlandıktan sonra
        // otomatik çekim kontrol edilir.
        _checkAutoCapture();
      } else {
        _liveAiBusy = false;
      }
    }
  }

  // =====================================================
  // AUTO CAPTURE
  // =====================================================

  bool get _phoneStable =>
      _movementLevel < 0.8;

  bool get _levelStable =>
      _levelTip.contains('dengeli');

  bool get _aiReady =>
      _aiStatus == 'good';

  void _toggleAutoCapture() {
    setState(() {
      _autoCaptureEnabled =
          !_autoCaptureEnabled;
    });

    if (!_autoCaptureEnabled) {
      _cancelAutoCapture();
    } else {
      _checkAutoCapture();
    }
  }

  void _checkAutoCapture() {
    if (!_autoCaptureEnabled ||
        !_liveAiEnabled) {
      _cancelAutoCapture();

      return;
    }

    if (_aiReady &&
        _phoneStable &&
        _levelStable &&
        !_liveAiBusy &&
        !_takingUserPhoto &&
        !_autoCaptureCountdown) {
      _startAutoCaptureCountdown();
    } else if (!_aiReady ||
        !_phoneStable ||
        !_levelStable) {
      _cancelAutoCapture();
    }
  }

  void _startAutoCaptureCountdown() {
    _autoCaptureTimer?.cancel();

    setState(() {
      _autoCaptureCountdown = true;
      _countdown = 2;
    });

    _runCountdown();
  }

  void _runCountdown() {
    _autoCaptureTimer =
        Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final stillReady =
            _aiReady &&
                _phoneStable &&
                _levelStable;

        if (!stillReady ||
            !_autoCaptureEnabled) {
          timer.cancel();

          _cancelAutoCapture();

          return;
        }

        if (_countdown > 1) {
          setState(() {
            _countdown--;
          });

          return;
        }

        timer.cancel();

        setState(() {
          _autoCaptureCountdown =
              false;
        });

        await _takePhoto();
      },
    );
  }

  void _cancelAutoCapture() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;

    if (_autoCaptureCountdown &&
        mounted) {
      setState(() {
        _autoCaptureCountdown =
            false;

        _countdown = 2;
      });
    }
  }

  // =====================================================
  // SENSOR
  // =====================================================

  void _startMotionAssistant() {
    _accelerometerSubscription =
        accelerometerEventStream()
            .listen(
      (event) {
        final magnitude = sqrt(
          event.x * event.x +
              event.y * event.y +
              event.z * event.z,
        );

        final movement =
            (magnitude - 9.81).abs();

        if (!mounted) {
          return;
        }

        String movementText;

        if (movement > 2.8) {
          movementText =
              '⚠ Telefon hareket ediyor';
        } else if (movement > 1.2) {
          movementText =
              'Telefonu sabit tut';
        } else {
          movementText =
              '✓ Telefon sabit';
        }

        final changed =
            movementText !=
                    _movementTip ||
                (movement -
                            _movementLevel)
                        .abs() >
                    0.2;

        if (changed) {
          setState(() {
            _movementLevel =
                movement;

            _movementTip =
                movementText;
          });

          if (_autoCaptureCountdown &&
              movement > 0.8) {
            _cancelAutoCapture();
          }
        }
      },
      onError: (error) {
        debugPrint(
          'Accelerometer error: $error',
        );
      },
    );

    _gyroscopeSubscription =
        gyroscopeEventStream()
            .listen(
      (event) {
        if (!mounted) {
          return;
        }

        String levelText;

        if (event.x.abs() > 0.65) {
          levelText =
              'Telefonu daha düz tut';
        } else if (event.y.abs() >
            0.65) {
          levelText =
              'Telefonu biraz düzleştir';
        } else {
          levelText =
              '✓ Kadraj dengeli';
        }

        final changed =
            levelText != _levelTip ||
                (event.x - _gyroX)
                        .abs() >
                    0.1 ||
                (event.y - _gyroY)
                        .abs() >
                    0.1;

        if (changed) {
          setState(() {
            _gyroX = event.x;
            _gyroY = event.y;

            _levelTip =
                levelText;
          });
        }
      },
      onError: (error) {
        debugPrint(
          'Gyroscope error: $error',
        );
      },
    );
  }

  // =====================================================
  // ANA ÖZNE / DOKUNARAK ODAK
  // =====================================================

  Future<void> _handlePreviewTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    // Ana özne zaten kilitliyse ekrana tekrar dokunmak kilidi kaldırır.
    if (_subjectLocked) {
      await _clearSubjectLock();
      return;
    }

    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    if (width <= 0 || height <= 0) return;

    final normalized = Offset(
      (details.localPosition.dx / width).clamp(0.0, 1.0),
      (details.localPosition.dy / height).clamp(0.0, 1.0),
    );

    setState(() {
      _subjectLocked = true;
      _subjectPoint = normalized;
    });

    try {
      await controller.setFocusPoint(normalized);
    } catch (_) {}

    try {
      await controller.setExposurePoint(normalized);
    } catch (_) {}

    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}

    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}

    if (_aiAutoProEnabled && !_liveAiBusy) {
      _captureAndAnalyzeLiveFrame();
    }
  }

  Future<void> _clearSubjectLock() async {
    final controller = _controller;

    setState(() {
      _subjectLocked = false;
      _subjectPoint = null;
    });

    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setFocusPoint(null);
      } catch (_) {}

      try {
        await controller.setExposurePoint(null);
      } catch (_) {}

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}

      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      if (_aiAutoProEnabled) {
        await _applyAutoProCameraSettings();
      }
    }
  }

  String get _subjectModeLabel {
    if (!_subjectLocked || _subjectPoint == null) {
      return _selectedFilter;
    }

    final x = (_subjectPoint!.dx * 100).round();
    final y = (_subjectPoint!.dy * 100).round();

    return '$_selectedFilter | ANA ÖZNE kilitli: x=$x%, y=$y%. '
        'Kalabalıktaki diğer kişileri ana özne kabul etme.';
  }

  // =====================================================
  // AI AUTO PRO
  // =====================================================

  Future<void> _toggleAiAutoPro() async {
    final next = !_aiAutoProEnabled;

    setState(() {
      _aiAutoProEnabled = next;
      _liveAiEnabled = next;

      if (next) {
        _aiStatus = 'adjust';
        _aiMainTip = 'AI AUTO PRO sahneyi optimize ediyor...';
      } else {
        _aiStatus = 'idle';
        _aiMainTip = 'AI AUTO PRO kapalı.';
        _aiCompositionTip = '';
        _aiLightTip = '';
        _aiSubjectTip = '';
      }
    });

    if (next) {
      await _applyAutoProCameraSettings();
      _startLiveAiTimer();
      _captureAndAnalyzeLiveFrame();
    } else {
      _liveAiTimer?.cancel();
    }
  }

  Future<void> _applyAutoProCameraSettings() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}

    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}

    try {
      await controller.setFlashMode(FlashMode.off);
      _flashEnabled = false;
    } catch (_) {}

    double exposure = 0.0;
    double preferredZoom = 1.0;
    String cinematicGuide = '';
    String stabilityGuide = '';

    switch (_selectedFilter) {
      case 'Portre':
        exposure = 0.20;
        preferredZoom = 1.35;
        break;

      case 'Gece':
        exposure = 0.35;
        preferredZoom = 1.0;
        stabilityGuide = _phoneStable
            ? '✓ Sabitlik iyi'
            : 'Telefonu sabitle';
        break;

      case 'Sinematik':
        exposure = -0.15;
        preferredZoom = 1.0;
        cinematicGuide = _movementLevel < 0.8
            ? 'Yavaş ve sabit hareket'
            : 'Hareketi yavaşlat';
        break;

      case 'Astro':
        exposure = 0.45;
        preferredZoom = 1.0;
        stabilityGuide = _phoneStable
            ? '✓ Astro için yeterince sabit'
            : 'Astro için telefonu sabitle';
        break;

      case 'Fotoğraf':
        exposure = 0.0;
        preferredZoom = 1.0;
        break;

      case 'Pro':
        exposure = 0.0;
        preferredZoom = 1.0;
        break;
    }

    try {
      final minExposure = await controller.getMinExposureOffset();
      final maxExposure = await controller.getMaxExposureOffset();
      final safeExposure =
          exposure.clamp(minExposure, maxExposure).toDouble();
      await controller.setExposureOffset(safeExposure);
      _currentExposure = safeExposure;
    } catch (_) {}

    try {
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final safeZoom =
          preferredZoom.clamp(minZoom, maxZoom).toDouble();
      await controller.setZoomLevel(safeZoom);
      _currentZoom = safeZoom;
    } catch (_) {}

    if (_subjectLocked && _subjectPoint != null) {
      try {
        await controller.setFocusPoint(_subjectPoint);
      } catch (_) {}

      try {
        await controller.setExposurePoint(_subjectPoint);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _cinematicGuide = cinematicGuide;
        _stabilityGuide = stabilityGuide;
      });
    }
  }

  Future<void> _applyAiDrivenAdjustments() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final combined = [
      _aiMainTip,
      _aiLightTip,
      _aiCompositionTip,
      _aiSubjectTip,
    ].join(' ').toLowerCase();

    double exposureDelta = 0.0;

    // AI'nin ışık yorumunu gerçek pozlama telafisine çevir.
    if (combined.contains('karanlık') ||
        combined.contains('az ışık') ||
        combined.contains('ışık düşük') ||
        combined.contains('daha aydınlık') ||
        combined.contains('aydınlat')) {
      exposureDelta += 0.35;
    }

    if (combined.contains('çok karanlık')) {
      exposureDelta += 0.20;
    }

    if (combined.contains('fazla parlak') ||
        combined.contains('çok parlak') ||
        combined.contains('aşırı ışık') ||
        combined.contains('pozlamayı düşür') ||
        combined.contains('ışığı azalt')) {
      exposureDelta -= 0.35;
    }

    // Mod tabanı + AI düzeltmesi.
    double modeBaseExposure = 0.0;
    switch (_selectedFilter) {
      case 'Portre':
        modeBaseExposure = 0.15;
        break;
      case 'Gece':
        modeBaseExposure = 0.40;
        break;
      case 'Sinematik':
        modeBaseExposure = -0.20;
        break;
      case 'Astro':
        modeBaseExposure = 0.55;
        break;
      case 'Fotoğraf':
      case 'Pro':
        modeBaseExposure = 0.0;
        break;
    }

    final requestedExposure = modeBaseExposure + exposureDelta;

    try {
      final minExposure = await controller.getMinExposureOffset();
      final maxExposure = await controller.getMaxExposureOffset();
      final safeExposure =
          requestedExposure.clamp(minExposure, maxExposure).toDouble();
      await controller.setExposureOffset(safeExposure);
      _currentExposure = safeExposure;
    } catch (_) {}

    // Ana özne varsa AF/AE her AI döngüsünde o noktada tutulur.
    final targetPoint =
        _subjectLocked && _subjectPoint != null
            ? _subjectPoint!
            : const Offset(0.5, 0.5);

    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(targetPoint);
    } catch (_) {}

    try {
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setExposurePoint(targetPoint);
    } catch (_) {}

    // Modların gerçekten farklı davranması için lens/zoom karakteri.
    double requestedZoom = 1.0;
    switch (_selectedFilter) {
      case 'Portre':
        requestedZoom = 1.45;
        break;
      case 'Sinematik':
        requestedZoom = 1.10;
        break;
      case 'Gece':
      case 'Astro':
      case 'Fotoğraf':
      case 'Pro':
        requestedZoom = 1.0;
        break;
    }

    try {
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final safeZoom =
          requestedZoom.clamp(minZoom, maxZoom).toDouble();
      await controller.setZoomLevel(safeZoom);
      _currentZoom = safeZoom;
    } catch (_) {}

    // Flaş davranışı modlara göre değişir.
    try {
      if (_selectedFilter == 'Fotoğraf' ||
          _selectedFilter == 'Portre') {
        final lowLight = combined.contains('karanlık') ||
            combined.contains('az ışık') ||
            combined.contains('ışık düşük');
        await controller.setFlashMode(
          lowLight ? FlashMode.auto : FlashMode.off,
        );
      } else {
        await controller.setFlashMode(FlashMode.off);
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  String get _lightHudText {
    final text = _aiLightTip.toLowerCase();

    if (_liveAiBusy) return 'IŞIK\\nANALİZ';

    if (text.contains('karanlık') ||
        text.contains('az ışık') ||
        text.contains('düşük')) {
      return 'IŞIK\\nARTIYOR';
    }

    if (text.contains('parlak') ||
        text.contains('fazla')) {
      return 'IŞIK\\nAZALIYOR';
    }

    if (_aiStatus == 'good') return 'IŞIK\\nİYİ';

    return 'IŞIK\\nDENGELİ';
  }

  String get _compositionHudText {
    if (_subjectLocked) return 'ÖZNE\\nKİLİTLİ';

    if (_aiStatus == 'good') return 'MEKAN\\nDENGELİ';

    final tip = _aiCompositionTip.toLowerCase();
    if (tip.contains('sol')) return 'KADRAJ\\nSOLA';
    if (tip.contains('sağ')) return 'KADRAJ\\nSAĞA';

    return 'MEKAN\\nDENGELİ';
  }

  void _toggleSpotMode() {
    setState(() {
      _spotModeEnabled = !_spotModeEnabled;
    });

    if (_aiAutoProEnabled && !_liveAiBusy) {
      _captureAndAnalyzeLiveFrame();
    }
  }

  // =====================================================
  // MODE
  // =====================================================

  void _selectFilter(String filter) {
    _cancelAutoCapture();

    setState(() {
      _selectedFilter = filter;

      if (_liveAiEnabled) {
        _aiMainTip =
            'Yeni moda göre kadraj inceleniyor...';
      }
    });

    if (_aiAutoProEnabled) {
      _applyAutoProCameraSettings();
    }

    if (_liveAiEnabled &&
        !_liveAiBusy) {
      _captureAndAnalyzeLiveFrame();
    }
  }

  Color _filterOverlayColor() {
    switch (_selectedFilter) {
      case 'Portre':
        return const Color(0x0DFFC15A);
      case 'Gece':
        return const Color(0x22002040);
      case 'Sinematik':
        return const Color(0x12000000);
      case 'Astro':
        return const Color(0x2600102A);
      default:
        return Colors.transparent;
    }
  }

  Color _statusColor() {
    if (_aiStatus == 'good') {
      return const Color(
        0xFF4ADE80,
      );
    }

    if (_aiStatus == 'warning') {
      return const Color(
        0xFFFF7043,
      );
    }

    return const Color(
      0xFFFFC107,
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _liveAiTimer?.cancel();

    _autoCaptureTimer?.cancel();

    _accelerometerSubscription
        ?.cancel();

    _gyroscopeSubscription
        ?.cancel();

    _controller?.dispose();

    super.dispose();
  }

  // =====================================================
  // SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor:
            Colors.black,
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_controller == null ||
        !_controller!
            .value.isInitialized) {
      return Scaffold(
        backgroundColor:
            Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment:
                    Alignment
                        .centerLeft,
                child:
                    IconButton(
                  icon:
                      const Icon(
                    Icons.close,
                    color:
                        Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Kamera başlatılamadı.',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
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
      backgroundColor:
          Colors.black,
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
                    final previewSize =
                        _controller!.value.previewSize;

                    Widget preview = CameraPreview(
                      _controller!,
                    );

                    if (previewSize != null) {
                      preview = FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: previewSize.height,
                          height: previewSize.width,
                          child: CameraPreview(
                            _controller!,
                          ),
                        ),
                      );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _handlePreviewTap(
                          details,
                          constraints,
                        );
                      },
                      onLongPress: _clearSubjectLock,
                      child: preview,
                    );
                  },
                ),
              ),
            ),

            Positioned(
              top: 70,
              left: 8,
              right: 8,
              bottom: 218,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: IgnorePointer(
                  child: Container(
                    color: _filterOverlayColor(),
                  ),
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
                    child: CameraGrid(),
                  ),
                ),
              ),

            if (_subjectLocked &&
                _subjectPoint != null)
              Positioned(
                top: 70,
                left: 8,
                right: 8,
                bottom: 218,
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final point = Offset(
                        _subjectPoint!.dx *
                            constraints.maxWidth,
                        _subjectPoint!.dy *
                            constraints.maxHeight,
                      );

                      return Stack(
                        children: [
                          Positioned(
                            left: point.dx - 34,
                            top: point.dy - 34,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(
                                    0xFFFFC107,
                                  ),
                                  width: 2,
                                ),
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                              ),
                              child: const Align(
                                alignment:
                                    Alignment.topRight,
                                child: Padding(
                                  padding:
                                      EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: Color(
                                      0xFFFFC107,
                                    ),
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

            // TOP CONTROLS
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CameraCircleButton(
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
                  CameraCircleButton(
                    icon: _showGrid ? Icons.grid_on : Icons.grid_off,
                    onTap: () {
                      setState(() {
                        _showGrid = !_showGrid;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  CameraCircleButton(
                    icon: _spotModeEnabled
                        ? Icons.location_on
                        : Icons.location_on_outlined,
                    onTap: _toggleSpotMode,
                  ),
                ],
              ),
            ),

            // AI CARD
            if (_showAssistant && !_aiAutoProEnabled)
              Positioned(
                top: 70,
                left: 14,
                right: 14,
                child:
                    LiveAssistantCard(
                  liveAiEnabled:
                      _liveAiEnabled,

                  liveAiBusy:
                      _liveAiBusy,

                  autoCaptureEnabled:
                      _autoCaptureEnabled,

                  autoCaptureCountdown:
                      _autoCaptureCountdown,

                  countdown:
                      _countdown,

                  status:
                      _aiStatus,

                  statusColor:
                      _statusColor(),

                  mainTip:
                      _aiMainTip,

                  compositionTip:
                      _aiCompositionTip,

                  lightTip:
                      _aiLightTip,

                  movementTip:
                      _movementTip,

                  levelTip:
                      _levelTip,

                  onToggleLiveAi:
                      _toggleLiveAi,

                  onToggleAutoCapture:
                      _toggleAutoCapture,
                ),
              ),

            if (_aiAutoProEnabled)
              Positioned(
                top: 88,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.62),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    constraints: const BoxConstraints(
                      maxWidth: 330,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_liveAiBusy)
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFC107),
                            ),
                          )
                        else
                          Icon(
                            _aiStatus == 'warning'
                                ? Icons.warning_amber_rounded
                                : Icons.auto_awesome,
                            size: 16,
                            color: _aiStatus == 'warning'
                                ? Colors.orangeAccent
                                : const Color(0xFFFFC107),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _liveAiBusy
                                ? 'Sahne analiz ediliyor...'
                                : (_aiMainTip.trim().isNotEmpty
                                    ? _aiMainTip
                                    : 'AI AUTO PRO aktif'),
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
                        Icons.person_pin_circle_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_currentZoom.toStringAsFixed(1)}x',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFC107),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'ZOOM',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                        ),
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
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                        ),
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
                      const SizedBox(height: 7),
                      Text(
                        'EV ${_currentExposure >= 0 ? '+' : ''}${_currentExposure.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 8.5,
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

            if (_spotModeEnabled ||
                _cinematicGuide.isNotEmpty ||
                _stabilityGuide.isNotEmpty ||
                _subjectLocked)
              Positioned(
                left: 14,
                right: 14,
                bottom: 215,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_subjectLocked)
                      const _CameraStatusChip(
                        icon: Icons.lock,
                        text: 'ANA ÖZNE',
                      ),
                    if (_spotModeEnabled)
                      const _CameraStatusChip(
                        icon: Icons.location_on,
                        text: 'SPOT MODU',
                      ),
                    if (_cinematicGuide.isNotEmpty)
                      _CameraStatusChip(
                        icon: Icons.movie_outlined,
                        text: _cinematicGuide,
                      ),
                    if (_stabilityGuide.isNotEmpty)
                      _CameraStatusChip(
                        icon: Icons.screen_rotation_outlined,
                        text: _stabilityGuide,
                      ),
                  ],
                ),
              ),

            if (!_subjectLocked)
              Positioned(
                left: 0,
                right: 0,
                bottom: 224,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.52),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Ana özne: dokunarak kilitle • tekrar dokunarak kaldır',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // MODES
            Positioned(
              left: 0,
              right: 0,
              bottom: 155,
              child: SizedBox(
                height: 52,
                child:
                    ListView.separated(
                  scrollDirection:
                      Axis.horizontal,

                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        14,
                  ),

                  itemCount:
                      _filters.length,

                  separatorBuilder:
                      (
                    context,
                    index,
                  ) {
                    return const SizedBox(
                      width: 8,
                    );
                  },

                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final filter =
                        _filters[
                            index];

                    final selected =
                        filter ==
                            _selectedFilter;

                    return GestureDetector(
                      onTap: () {
                        _selectFilter(
                          filter,
                        );
                      },

                      child:
                          AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds:
                              180,
                        ),

                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              18,
                          vertical:
                              10,
                        ),

                        decoration:
                            BoxDecoration(
                          color: selected
                              ? const Color(
                                  0xFFFFC107,
                                )
                              : Colors
                                  .black
                                  .withOpacity(
                                    .62,
                                  ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            24,
                          ),
                        ),

                        child:
                            Center(
                          child:
                              Text(
                            filter,

                            style:
                                TextStyle(
                              color: selected
                                  ? Colors
                                      .black
                                  : Colors
                                      .white,

                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // BOTTOM CAMERA CONTROLS
            Positioned(
              left: 25,
              right: 25,
              bottom: 28,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  CameraCircleButton(
                    icon: Icons
                        .photo_library_outlined,

                    size: 56,

                    onTap:
                        _pickFromGallery,
                  ),

                  GestureDetector(
                    onTap:
                        _takePhoto,

                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds:
                            200,
                      ),

                      width: 86,
                      height: 86,

                      padding:
                          const EdgeInsets
                              .all(
                        6,
                      ),

                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape
                                .circle,

                        border:
                            Border.all(
                          color: _aiReady
                              ? const Color(
                                  0xFF4ADE80,
                                )
                              : Colors
                                  .white,

                          width:
                              _aiReady
                                  ? 6
                                  : 4,
                        ),
                      ),

                      child:
                          Container(
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,

                          color: _aiReady
                              ? const Color(
                                  0xFF4ADE80,
                                )
                              : const Color(
                                  0xFFFFC107,
                                ),
                        ),
                      ),
                    ),
                  ),

                  CameraCircleButton(
                    icon: Icons
                        .cameraswitch_outlined,

                    size: 56,

                    onTap:
                        _toggleCamera,
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

class _CameraStatusChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CameraStatusChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFFFFC107),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// LIVE AI CARD
// =====================================================

class LiveAssistantCard
    extends StatelessWidget {
  final bool liveAiEnabled;
  final bool liveAiBusy;

  final bool autoCaptureEnabled;
  final bool autoCaptureCountdown;

  final int countdown;

  final String status;

  final Color statusColor;

  final String mainTip;
  final String compositionTip;
  final String lightTip;

  final String movementTip;
  final String levelTip;

  final VoidCallback onToggleLiveAi;
  final VoidCallback
      onToggleAutoCapture;

  const LiveAssistantCard({
    super.key,
    required this.liveAiEnabled,
    required this.liveAiBusy,
    required this.autoCaptureEnabled,
    required this.autoCaptureCountdown,
    required this.countdown,
    required this.status,
    required this.statusColor,
    required this.mainTip,
    required this.compositionTip,
    required this.lightTip,
    required this.movementTip,
    required this.levelTip,
    required this.onToggleLiveAi,
    required this.onToggleAutoCapture,
  });

  bool get ready =>
      status == 'good';

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 250,
      ),

      padding:
          const EdgeInsets.all(
        13,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.black
                .withOpacity(
          .80,
        ),

        borderRadius:
            BorderRadius
                .circular(
          20,
        ),

        border:
            Border.all(
          color:
              statusColor
                  .withOpacity(
            .80,
          ),

          width:
              ready ? 2 : 1,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? Icons
                        .check_circle
                    : Icons
                        .auto_awesome,

                color:
                    statusColor,

                size:
                    ready
                        ? 25
                        : 21,
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Text(
                  ready
                      ? 'Çekime Hazır'
                      : 'AI Çekim Asistanı',

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontWeight:
                        FontWeight
                            .w800,

                    fontSize:
                        17,
                  ),
                ),
              ),

              if (liveAiBusy)
                const SizedBox(
                  width: 18,
                  height: 18,

                  child:
                      CircularProgressIndicator(
                    strokeWidth:
                        2,
                  ),
                ),

              const SizedBox(
                width: 8,
              ),

              Switch(
                value:
                    liveAiEnabled,

                onChanged: (
                  value,
                ) {
                  onToggleLiveAi();
                },
              ),
            ],
          ),

          if (ready) ...[
            const SizedBox(
              height: 5,
            ),

            Text(
              autoCaptureCountdown
                  ? '📸 $countdown saniye sabit kal...'
                  : '✓ Kadraj hazır — çekebilirsin.',

              style:
                  const TextStyle(
                color:
                    Colors.white,

                fontSize:
                    16,

                fontWeight:
                    FontWeight
                        .w700,
              ),
            ),
          ] else ...[
            const SizedBox(
              height: 6,
            ),

            AssistantTipRow(
              icon: Icons
                  .center_focus_strong,

              text:
                  mainTip,

              highlight:
                  true,
            ),

            if (compositionTip
                .isNotEmpty)
              AssistantTipRow(
                icon:
                    Icons.crop_free,

                text:
                    compositionTip,
              ),

            if (lightTip
                .isNotEmpty)
              AssistantTipRow(
                icon: Icons
                    .light_mode_outlined,

                text:
                    lightTip,
              ),
          ],

          const SizedBox(
            height: 4,
          ),

          const Divider(
            color:
                Colors.white12,
          ),

          Row(
            children: [
              Expanded(
                child: Text(
                  movementTip,

                  maxLines: 1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.white60,

                    fontSize:
                        11,
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Text(
                  levelTip,

                  maxLines: 1,

                  textAlign:
                      TextAlign.right,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.white60,

                    fontSize:
                        11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 3,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .camera_alt_outlined,

                color:
                    Color(
                  0xFFFFC107,
                ),

                size: 17,
              ),

              const SizedBox(
                width: 7,
              ),

              const Expanded(
                child: Text(
                  'Otomatik çekim',

                  style:
                      TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        12.5,

                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ),

              Switch(
                value:
                    autoCaptureEnabled,

                onChanged: (
                  value,
                ) {
                  onToggleAutoCapture();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// TIP ROW
// =====================================================

class AssistantTipRow
    extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const AssistantTipRow({
    super.key,
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            icon,

            color:
                const Color(
              0xFFFFC107,
            ),

            size: 17,
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: Text(
              text,

              maxLines:
                  highlight
                      ? 2
                      : 1,

              overflow:
                  TextOverflow
                      .ellipsis,

              style:
                  TextStyle(
                color:
                    Colors.white,

                fontSize:
                    highlight
                        ? 14
                        : 12.5,

                fontWeight:
                    highlight
                        ? FontWeight
                            .w700
                        : FontWeight
                            .w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// GRID
// =====================================================

class CameraGrid
    extends StatelessWidget {
  const CameraGrid({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter:
          GridPainter(),
    );
  }
}

class GridPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color =
          Colors.white
              .withOpacity(
        .32,
      )
      ..strokeWidth = 1;

    final thirdWidth =
        size.width / 3;

    final thirdHeight =
        size.height / 3;

    canvas.drawLine(
      Offset(
        thirdWidth,
        0,
      ),
      Offset(
        thirdWidth,
        size.height,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        thirdWidth * 2,
        0,
      ),
      Offset(
        thirdWidth * 2,
        size.height,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        0,
        thirdHeight,
      ),
      Offset(
        size.width,
        thirdHeight,
      ),
      paint,
    );

    canvas.drawLine(
      Offset(
        0,
        thirdHeight * 2,
      ),
      Offset(
        size.width,
        thirdHeight * 2,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}

// =====================================================
// CIRCLE BUTTON
// =====================================================

class CameraCircleButton
    extends StatelessWidget {
  final IconData icon;

  final VoidCallback onTap;

  final double size;

  const CameraCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.black
              .withOpacity(
        .58,
      ),

      shape:
          const CircleBorder(),

      child: InkWell(
        customBorder:
            const CircleBorder(),

        onTap: onTap,

        child: SizedBox(
          width: size,
          height: size,

          child: Icon(
            icon,

            color:
                Colors.white,
          ),
        ),
      ),
    );
  }
}

// =====================================================
// PHOTO ANALYSIS SCREEN
// =====================================================

class PhotoPreviewScreen
    extends StatefulWidget {
  final String imagePath;

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<PhotoPreviewScreen>
      createState() =>
          _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState
    extends State<PhotoPreviewScreen> {
  bool _analyzing = false;

  PhotoAnalysis? _analysis;

  String? _error;

  Future<void> _analyze() async {
    setState(() {
      _analyzing = true;
      _analysis = null;
      _error = null;
    });

    try {
      final result =
          await AiService
              .analyzePhoto(
        widget.imagePath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _analysis =
            result;

        _analyzing =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          e.toString(),
        );

        _analyzing =
            false;
      });
    }
  }

  String _friendlyError(
    String error,
  ) {
    if (error.contains('502')) {
      return 'AI servisine ulaşılamıyor. Birkaç saniye sonra tekrar deneyin.';
    }

    if (error.contains('429')) {
      return 'AI kullanım limiti dolmuş olabilir.';
    }

    if (error.contains('500')) {
      return 'Fotoğraf analizi sırasında sunucu hatası oluştu.';
    }

    return 'Fotoğraf analizi sırasında bir hata oluştu.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFF0D1117,
      ),

      appBar: AppBar(
        backgroundColor:
            const Color(
          0xFF0D1117,
        ),

        foregroundColor:
            Colors.white,

        title:
            const Text(
          'Fotoğraf Analizi',
        ),
      ),

      body: ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),

        children: [
          ClipRRect(
            borderRadius:
                BorderRadius
                    .circular(
              18,
            ),

            child:
                Image.file(
              File(
                widget.imagePath,
              ),

              height: 340,

              fit:
                  BoxFit.cover,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          if (_analysis ==
              null)
            SizedBox(
              height: 54,

              child:
                  ElevatedButton
                      .icon(
                onPressed:
                    _analyzing
                        ? null
                        : _analyze,

                icon:
                    _analyzing
                        ? const SizedBox(
                            width:
                                20,
                            height:
                                20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .auto_awesome,
                          ),

                label:
                    Text(
                  _analyzing
                      ? 'Analiz ediliyor...'
                      : 'Fotoğrafı Analiz Et',
                ),
              ),
            ),

          if (_error !=
              null) ...[
            const SizedBox(
              height: 16,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .all(
                14,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.red
                        .withOpacity(
                  .12,
                ),

                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
              ),

              child:
                  Text(
                _error!,

                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          ],

          if (_analysis !=
              null) ...[
            ScoreCard(
              analysis:
                  _analysis!,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'AI Değerlendirmesi',

              style:
                  TextStyle(
                fontSize: 21,

                fontWeight:
                    FontWeight
                        .bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              _analysis!
                  .summary,

              style:
                  const TextStyle(
                color:
                    Colors.white70,

                height: 1.5,

                fontSize:
                    15,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'Fotoğrafı iyileştirmek için',

              style:
                  TextStyle(
                fontSize: 20,

                fontWeight:
                    FontWeight
                        .bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            ..._analysis!
                .suggestions
                .map(
              (
                suggestion,
              ) {
                return Container(
                  margin:
                      const EdgeInsets
                          .only(
                    bottom:
                        10,
                  ),

                  padding:
                      const EdgeInsets
                          .all(
                    14,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFF151A22,
                    ),

                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),

                  child:
                      Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      const Icon(
                        Icons
                            .auto_awesome,

                        color:
                            Color(
                          0xFFFFC107,
                        ),

                        size:
                            20,
                      ),

                      const SizedBox(
                        width:
                            10,
                      ),

                      Expanded(
                        child:
                            Text(
                          suggestion,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            OutlinedButton.icon(
              onPressed:
                  _analyze,

              icon:
                  const Icon(
                Icons.refresh,
              ),

              label:
                  const Text(
                'Tekrar Analiz Et',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// SCORE CARD
// =====================================================

class ScoreCard
    extends StatelessWidget {
  final PhotoAnalysis analysis;

  const ScoreCard({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 20,
      ),

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF151A22,
        ),

        borderRadius:
            BorderRadius
                .circular(
          18,
        ),
      ),

      child: Column(
        children: [
          Text(
            '${analysis.score}/100',

            style:
                const TextStyle(
              fontSize:
                  40,

              fontWeight:
                  FontWeight
                      .w900,

              color:
                  Color(
                0xFFFFC107,
              ),
            ),
          ),

          const Text(
            'Fotoğraf Skoru',

            style:
                TextStyle(
              color:
                  Colors.white54,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          ScoreRow(
            title:
                'Kompozisyon',

            value:
                analysis
                    .composition,
          ),

          ScoreRow(
            title:
                'Işık',

            value:
                analysis
                    .lighting,
          ),

          ScoreRow(
            title:
                'Perspektif',

            value:
                analysis
                    .perspective,
          ),

          ScoreRow(
            title:
                'Netlik',

            value:
                analysis
                    .sharpness,
          ),
        ],
      ),
    );
  }
}

class ScoreRow
    extends StatelessWidget {
  final String title;
  final int value;

  const ScoreRow({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        vertical: 6,
      ),

      child: Row(
        children: [
          Expanded(
            child:
                Text(
              title,
            ),
          ),

          Text(
            '$value/10',

            style:
                const TextStyle(
              fontWeight:
                  FontWeight
                      .bold,
            ),
          ),
        ],
      ),
    );
  }
}
