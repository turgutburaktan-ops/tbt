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
        mode: _selectedFilter,
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

    // Modlara göre cihazın desteklediği güvenli kamera ayarları.
    try {
      switch (_selectedFilter) {
        case 'Portre':
          await controller.setExposureOffset(0.25);
          break;
        case 'Gece':
          await controller.setExposureOffset(0.45);
          break;
        case 'Sinematik':
          await controller.setExposureOffset(-0.15);
          break;
        case 'Astro':
          await controller.setExposureOffset(0.60);
          break;
        case 'Fotoğraf':
          await controller.setExposureOffset(0.0);
          break;
        case 'Pro':
          // Pro modunda kullanıcıya mümkün olduğunca nötr başlangıç ver.
          await controller.setExposureOffset(0.0);
          break;
      }
    } catch (_) {}

    if (mounted) setState(() {});
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
            Positioned.fill(
              child:
                  CameraPreview(
                _controller!,
              ),
            ),

            Positioned.fill(
              child:
                  IgnorePointer(
                child: Container(
                  color:
                      _filterOverlayColor(),
                ),
              ),
            ),

            if (_showGrid)
              const Positioned.fill(
                child:
                    IgnorePointer(
                  child:
                      CameraGrid(),
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
                top: 72,
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
                    child: Text(
                      _liveAiBusy
                          ? '✨ Sahne optimize ediliyor...'
                          : '✨ AI AUTO PRO aktif',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
