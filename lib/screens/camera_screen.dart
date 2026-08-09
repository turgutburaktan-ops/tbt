import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  int _cameraIndex = 0;
  bool _flashEnabled = false;
  bool _showGrid = true;
  bool _initializing = true;
  bool _showLiveAssistant = true;

  String _selectedFilter = 'Normal';

  String _liveTip =
      'Ana konuyu üçte birlik çizgilere yerleştir.';

  String _positionTip =
      'Konuyu üçte birlik çizgilerden birine yerleştir.';

  String _lightTip =
      'Işığı kontrol et.';

  String _stabilityTip =
      'Telefonu sabit tut.';

  final List<String> _filters = const [
    'Normal',
    'Golden',
    'Portrait',
    'Nature',
    'Night',
    'Architecture',
    'B&W',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _updateLiveAssistant();
  }

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
    if (_cameras.isEmpty) return;

    await _controller?.dispose();

    final newController = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await newController.initialize();

      _controller = newController;
      _cameraIndex = index;

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    } catch (e) {
      debugPrint('Kamera controller hatası: $e');

      await newController.dispose();

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;

    final nextIndex =
        (_cameraIndex + 1) % _cameras.length;

    await _startCamera(nextIndex);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    try {
      _flashEnabled = !_flashEnabled;

      await _controller!.setFlashMode(
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

  Future<void> _takePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _controller!.value.isTakingPicture) {
      return;
    }

    try {
      final image =
          await _controller!.takePicture();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoPreviewScreen(
            imagePath: image.path,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Fotoğraf çekme hatası: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );

      if (image == null || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoPreviewScreen(
            imagePath: image.path,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Galeri hatası: $e');
    }
  }

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;

      switch (filter) {
        case 'Golden':
          _liveTip =
              'Işığı yan taraftan al ve gölgeleri yumuşat.';
          break;

        case 'Portrait':
          _liveTip =
              'Yüzü üst üçte birlik çizgiye yaklaştır.';
          break;

        case 'Nature':
          _liveTip =
              'Ufku alt veya üst üçte birlik çizgiye taşı.';
          break;

        case 'Night':
          _liveTip =
              'Telefonu sabit tut ve güçlü ışıkları merkeze alma.';
          break;

        case 'Architecture':
          _liveTip =
              'Dikey çizgileri mümkün olduğunca paralel tut.';
          break;

        case 'B&W':
          _liveTip =
              'Kontrastı yüksek alanları ve güçlü gölgeleri kullan.';
          break;

        default:
          _liveTip =
              'Ana konuyu üçte birlik çizgilere yerleştir.';
      }
    });

    _updateLiveAssistant();
  }

  void _updateLiveAssistant() {
    if (!_showLiveAssistant) return;

    String positionTip;
    String lightTip;
    String stabilityTip;

    switch (_selectedFilter) {
      case 'Portrait':
        positionTip =
            'Yüzü üst üçte birlik çizgiye yaklaştır ve biraz boşluk bırak.';
        lightTip =
            'Yüzün önünden veya hafif yandan gelen yumuşak ışığı kullan.';
        stabilityTip =
            'Telefonu göz hizasında ve mümkün olduğunca sabit tut.';
        break;

      case 'Golden':
        positionTip =
            'Ana konuyu güneşin ters tarafındaki üçte birlik çizgiye yerleştir.';
        lightTip =
            'Altın saat ışığını yandan al; doğrudan kameraya çevirmemeye çalış.';
        stabilityTip =
            'Pozlamayı korumak için telefonu sabit tut.';
        break;

      case 'Nature':
        positionTip =
            'Ufku tam ortaya koyma; üst veya alt üçte birlik çizgiye taşı.';
        lightTip =
            'Gökyüzü çok parlaksa kamerayı biraz aşağı yönlendir.';
        stabilityTip =
            'Manzara çekiminde telefonu iki elle tut.';
        break;

      case 'Night':
        positionTip =
            'Parlak ışık kaynaklarını tam merkeze koyma.';
        lightTip =
            'Işık düşük. Telefonu mümkün olduğunca sabit tut.';
        stabilityTip =
            'Gece çekiminde hareket etme ve telefonu bir yere yaslamayı dene.';
        break;

      case 'Architecture':
        positionTip =
            'Binanın dikey çizgilerini ekran kenarlarına paralel tut.';
        lightTip =
            'Cephedeki gölge ve parlak alanların dengesini kontrol et.';
        stabilityTip =
            'Telefonu sağa veya sola eğmeden tut.';
        break;

      case 'B&W':
        positionTip =
            'Güçlü çizgileri ve geometrik şekilleri kadrajda öne çıkar.';
        lightTip =
            'Kontrastı artıran gölge ve ışık bölgelerini kullan.';
        stabilityTip =
            'Keskin çizgiler için telefonu sabit tut.';
        break;

      default:
        positionTip =
            'Ana konuyu sağ veya sol üçte birlik çizgiye yerleştir.';
        lightTip =
            'Ana konu çok karanlık veya aşırı parlak görünmemeli.';
        stabilityTip =
            'Çekim sırasında telefonu iki elle sabit tut.';
    }

    if (!mounted) return;

    setState(() {
      _positionTip = positionTip;
      _lightTip = lightTip;
      _stabilityTip = stabilityTip;
    });
  }

  Color _filterOverlayColor() {
    switch (_selectedFilter) {
      case 'Golden':
        return const Color(0x33FFC15A);

      case 'Portrait':
        return const Color(0x1AFFA0B5);

      case 'Nature':
        return const Color(0x1A5CB85C);

      case 'Night':
        return const Color(0x33002040);

      case 'Architecture':
        return const Color(0x1A9E9E9E);

      case 'B&W':
        return const Color(0x33000000);

      default:
        return Colors.transparent;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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

    if (_controller == null ||
        !_controller!.value.isInitialized) {
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
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Kamera başlatılamadı.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
            Positioned.fill(
              child: CameraPreview(
                _controller!,
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: _filterOverlayColor(),
                ),
              ),
            ),

            if (_showGrid)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CameraGrid(),
                ),
              ),

            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CameraCircleButton(
                    icon: Icons.close,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  CameraCircleButton(
                    icon: _flashEnabled
                        ? Icons.flash_on
                        : Icons.flash_off,
                    onTap: _toggleFlash,
                  ),
                  const SizedBox(width: 8),
                  CameraCircleButton(
                    icon: _showGrid
                        ? Icons.grid_on
                        : Icons.grid_off,
                    onTap: () {
                      setState(() {
                        _showGrid =
                            !_showGrid;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  CameraCircleButton(
                    icon: _showLiveAssistant
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    onTap: () {
                      setState(() {
                        _showLiveAssistant =
                            !_showLiveAssistant;
                      });
                    },
                  ),
                ],
              ),
            ),

            if (_showLiveAssistant)
              Positioned(
                top: 78,
                left: 14,
                right: 14,
                child: LiveAssistantCard(
                  mainTip: _liveTip,
                  positionTip: _positionTip,
                  lightTip: _lightTip,
                  stabilityTip:
                      _stabilityTip,
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 155,
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                  scrollDirection:
                      Axis.horizontal,
                  itemCount:
                      _filters.length,
                 separatorBuilder: (context, index) {
                    return const SizedBox(width: 8);
                 },
                  itemBuilder:
                      (context, index) {
                    final filter =
                        _filters[index];

                    final selected =
                        _selectedFilter ==
                            filter;

                    return GestureDetector(
                      onTap: () {
                        _selectFilter(
                          filter,
                        );
                      },
                      child: AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds: 180,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration:
                            BoxDecoration(
                          color: selected
                              ? const Color(
                                  0xFFFFC107,
                                )
                              : Colors.black
                                  .withOpacity(
                                    .58,
                                  ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            22,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style:
                                TextStyle(
                              color:
                                  selected
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

            Positioned(
              left: 20,
              right: 20,
              bottom: 32,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  CameraCircleButton(
                    icon:
                        Icons.photo_library_outlined,
                    size: 54,
                    onTap:
                        _pickFromGallery,
                  ),

                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 82,
                      height: 82,
                      padding:
                          const EdgeInsets.all(
                        6,
                      ),
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        border: Border.all(
                          color:
                              Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Container(
                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              Color(
                            0xFFFFC107,
                          ),
                        ),
                      ),
                    ),
                  ),

                  CameraCircleButton(
                    icon: Icons
                        .cameraswitch_outlined,
                    size: 54,
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

class LiveAssistantCard
    extends StatelessWidget {
  final String mainTip;
  final String positionTip;
  final String lightTip;
  final String stabilityTip;

  const LiveAssistantCard({
    super.key,
    required this.mainTip,
    required this.positionTip,
    required this.lightTip,
    required this.stabilityTip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            Colors.black.withOpacity(.72),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(
            0x44FFC107,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color:
                    Color(0xFFFFC107),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'AI Çekim Asistanı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AssistantTipRow(
            icon:
                Icons.center_focus_strong,
            text: mainTip,
          ),
          AssistantTipRow(
            icon:
                Icons.crop_free,
            text: positionTip,
          ),
          AssistantTipRow(
            icon:
                Icons.light_mode_outlined,
            text: lightTip,
          ),
          AssistantTipRow(
            icon:
                Icons.pan_tool_alt_outlined,
            text: stabilityTip,
          ),
        ],
      ),
    );
  }
}

class AssistantTipRow
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const AssistantTipRow({
    super.key,
    required this.icon,
    required this.text,
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
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color:
                const Color(
              0xFFFFC107,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraGrid
    extends StatelessWidget {
  const CameraGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(),
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
          Colors.white.withOpacity(.38)
      ..strokeWidth = 1;

    final thirdWidth =
        size.width / 3;
    final thirdHeight =
        size.height / 3;

    canvas.drawLine(
      Offset(thirdWidth, 0),
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
      Offset(0, thirdHeight),
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

class CameraCircleButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const CameraCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.black.withOpacity(.55),
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
// FOTOĞRAF ANALİZ EKRANI
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
          await AiService.analyzePhoto(
        widget.imagePath,
      );

      if (!mounted) return;

      setState(() {
        _analysis = result;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            _friendlyError(
          e.toString(),
        );
        _analyzing = false;
      });
    }
  }

  String _friendlyError(
    String error,
  ) {
    if (error.contains('502')) {
      return 'AI servisine şu anda ulaşılamıyor. Birkaç saniye sonra tekrar deneyin.';
    }

    if (error.contains('429')) {
      return 'AI kullanım limiti dolmuş olabilir. Lütfen daha sonra tekrar deneyin.';
    }

    if (error.contains('500')) {
      return 'Fotoğraf analizi sırasında bir sunucu hatası oluştu. Tekrar deneyin.';
    }

    return error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0D1117),
        foregroundColor:
            Colors.white,
        title: const Text(
          'Fotoğraf Analizi',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            child: Image.file(
              File(
                widget.imagePath,
              ),
              height: 340,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 20),

          if (_analysis == null)
            SizedBox(
              height: 54,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _analyzing
                        ? null
                        : _analyze,
                icon: _analyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
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
                label: Text(
                  _analyzing
                      ? 'Fotoğraf analiz ediliyor...'
                      : 'Fotoğrafı Analiz Et',
                ),
              ),
            ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.red
                    .withOpacity(
                  .12,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
              ),
              child: Text(
                _error!,
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          ],

          if (_analysis != null) ...[
            ScoreCard(
              analysis:
                  _analysis!,
            ),

            const SizedBox(height: 16),

            const Text(
              'AI Değerlendirmesi',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _analysis!.summary,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Fotoğrafı iyileştirmek için',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ..._analysis!
                .suggestions
                .map(
              (suggestion) =>
                  Container(
                margin:
                    const EdgeInsets
                        .only(
                  bottom: 10,
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
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Icon(
                      Icons
                          .auto_awesome,
                      size: 20,
                      color:
                          Color(
                        0xFFFFC107,
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        suggestion,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _analyze,
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
            BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        children: [
          Text(
            '${analysis.score}/100',
            style:
                const TextStyle(
              fontSize: 38,
              fontWeight:
                  FontWeight.w900,
              color:
                  Color(
                0xFFFFC107,
              ),
            ),
          ),

          const Text(
            'Fotoğraf Skoru',
            style: TextStyle(
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
                analysis.composition,
          ),

          ScoreRow(
            title: 'Işık',
            value:
                analysis.lighting,
          ),

          ScoreRow(
            title:
                'Perspektif',
            value:
                analysis.perspective,
          ),

          ScoreRow(
            title: 'Netlik',
            value:
                analysis.sharpness,
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
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
            ),
          ),
          Text(
            '$value/10',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
