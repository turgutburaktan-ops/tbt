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

  String _selectedFilter = 'Normal';
  String _liveTip = 'Ana konuyu üçte birlik çizgilere yerleştir.';

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

    final nextIndex = (_cameraIndex + 1) % _cameras.length;
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
        _flashEnabled ? FlashMode.torch : FlashMode.off,
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
      final image = await _controller!.takePicture();

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
      final image = await _picker.pickImage(
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
              left: 12,
              right: 12,
              top: 8,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  CameraCircleButton(
                    icon: Icons.close,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  Row(
                    children: [
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
                            _showGrid = !_showGrid;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Positioned(
              top: 72,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFC107)
                        .withOpacity(.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFC107),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _liveTip,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 118,
              child: SizedBox(
                height: 54,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final selected =
                        filter == _selectedFilter;

                    return ChoiceChip(
                      label: Text(filter),
                      selected: selected,
                      onSelected: (_) {
                        _selectFilter(filter);
                      },
                      selectedColor:
                          const Color(0xFFFFC107),
                      backgroundColor:
                          Colors.black.withOpacity(.55),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.black
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  CameraCircleButton(
                    icon: Icons.photo_library_outlined,
                    size: 54,
                    onTap: _pickFromGallery,
                  ),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                      ),
                    ),
                  ),
                  CameraCircleButton(
                    icon: Icons.cameraswitch_outlined,
                    size: 54,
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

class CameraGrid extends StatelessWidget {
  const CameraGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.38)
      ..strokeWidth = 1;

    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );

    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );

    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );

    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}

class CameraCircleButton extends StatelessWidget {
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
      color: Colors.black.withOpacity(.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<PhotoPreviewScreen> createState() =>
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
      final result = await AiService.analyzePhoto(
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
        _error = e.toString();
        _analyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        title: const Text(
          'Fotoğraf Analizi',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              File(widget.imagePath),
              height: 340,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 20),

          if (_analysis == null)
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed:
                    _analyzing ? null : _analyze,
                icon: _analyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome,
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],

          if (_analysis != null) ...[
            ScoreCard(
              analysis: _analysis!,
            ),

            const SizedBox(height: 16),

            const Text(
              'AI Değerlendirmesi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _analysis!.summary,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Fotoğrafı iyileştirmek için',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ..._analysis!.suggestions.map(
              (suggestion) => Container(
                margin:
                    const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF151A22),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Color(0xFFFFC107),
                    ),
                    const SizedBox(width: 10),
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
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Tekrar Analiz Et',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ScoreCard extends StatelessWidget {
  final PhotoAnalysis analysis;

  const ScoreCard({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151A22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '${analysis.score}/100',
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFC107),
            ),
          ),

          const Text(
            'Fotoğraf Skoru',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 20),

          ScoreRow(
            title: 'Kompozisyon',
            value: analysis.composition,
          ),

          ScoreRow(
            title: 'Işık',
            value: analysis.lighting,
          ),

          ScoreRow(
            title: 'Perspektif',
            value: analysis.perspective,
          ),

          ScoreRow(
            title: 'Netlik',
            value: analysis.sharpness,
          ),
        ],
      ),
    );
  }
}

class ScoreRow extends StatelessWidget {
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
      padding: const EdgeInsets.symmetric(
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
