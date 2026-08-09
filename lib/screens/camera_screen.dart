import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  int _cameraIndex = 0;
  bool _flashEnabled = false;
  bool _showGrid = true;
  bool _initializing = true;

  String _selectedFilter = 'Normal';
  String _liveTip = 'Ana konuyu üçte birlik çizgilere yerleştir.';

  final ImagePicker _picker = ImagePicker();

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
        setState(() {
          _initializing = false;
        });
        return;
      }

      await _startCamera(0);
    } catch (_) {
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

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller.initialize();

    _controller = controller;
    _cameraIndex = index;

    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;

    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera(nextIndex);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    _flashEnabled = !_flashEnabled;

    await _controller!.setFlashMode(
      _flashEnabled ? FlashMode.torch : FlashMode.off,
    );

    setState(() {});
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
          builder: (_) => _PhotoPreviewScreen(
            imagePath: image.path,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoPreviewScreen(
          imagePath: image.path,
        ),
      ),
    );
  }

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;

      switch (filter) {
        case 'Golden':
          _liveTip = 'Işığı yan taraftan al; gölgeleri yumuşat.';
          break;

        case 'Portrait':
          _liveTip = 'Yüzü üst üçte birlik çizgiye yaklaştır.';
          break;

        case 'Nature':
          _liveTip = 'Ufku alt veya üst üçte birlik çizgiye taşı.';
          break;

        case 'Night':
          _liveTip = 'Telefonu sabit tut ve parlak ışıkları merkeze alma.';
          break;

        case 'Architecture':
          _liveTip = 'Dikey çizgileri mümkün olduğunca paralel tut.';
          break;

        case 'B&W':
          _liveTip = 'Kontrastı yüksek alanları kullan.';
          break;

        default:
          _liveTip = 'Ana konuyu üçte birlik çizgilere yerleştir.';
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
                  child: _CameraGrid(),
                ),
              ),

            // ÜST BAR
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),

                  Row(
                    children: [
                      _CircleButton(
                        icon: _flashEnabled
                            ? Icons.flash_on
                            : Icons.flash_off,
                        onTap: _toggleFlash,
                      ),

                      const SizedBox(width: 8),

                      _CircleButton(
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

            // CANLI ÖNERİ
            Positioned(
              top: 74,
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

            // FİLTRELER
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
                  separatorBuilder: (, _) =>
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

            // ALT KAMERA KONTROLLERİ
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleButton(
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

                  _CircleButton(
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

class _CameraGrid extends StatelessWidget {
  const _CameraGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _CircleButton({
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

class _PhotoPreviewScreen extends StatelessWidget {
  final String imagePath;

  const _PhotoPreviewScreen({
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Fotoğraf'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Gerçek AI analizi 5. aşamada bağlanacak.',
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.auto_awesome,
                ),
                label: const Text(
                  'Fotoğrafı Analiz Et',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
