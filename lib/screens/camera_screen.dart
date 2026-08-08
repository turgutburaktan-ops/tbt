import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/photo_spot.dart';
import '../services/ai_service.dart';
import '../services/location_service.dart';
import 'analysis_screen.dart';

class CameraScreen extends StatefulWidget {
  final PhotoSpot? spot;

  const CameraScreen({super.key, this.spot});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool loading = true;
  bool flash = false;
  int cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera available');
      }

      controller = CameraController(
        cameras[cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller!.initialize();
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamera başlatılamadı: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2) return;
    cameraIndex = cameraIndex == 0 ? 1 : 0;
    await controller?.dispose();

    controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _takePhoto() async {
    if (controller == null || !controller!.value.isInitialized) return;

    try {
      final position = await LocationService.getCurrentPosition();
      final file = await controller!.takePicture();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            image: File(file.path),
            latitude: position?.latitude,
            longitude: position?.longitude,
            spot: widget.spot,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf çekilemedi: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final position = await LocationService.getCurrentPosition();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          image: File(picked.path),
          latitude: position?.latitude,
          longitude: position?.longitude,
          spot: widget.spot,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Kamera kullanılamıyor.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller!),

          SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 30),
                    ),
                    if (widget.spot != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('📍 ${widget.spot!.name}'),
                      ),
                    IconButton(
                      onPressed: () async {
                        flash = !flash;
                        await controller!.setFlashMode(
                          flash ? FlashMode.torch : FlashMode.off,
                        );
                        setState(() {});
                      },
                      icon: Icon(
                        flash ? Icons.flash_on : Icons.flash_off,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                if (widget.spot != null)
                  Container(
                    margin: const EdgeInsets.all(18),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.70),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFFFFC107)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Önerilen açı: ${widget.spot!.angle}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library, size: 32),
                      ),
                      GestureDetector(
                        onTap: _takePhoto,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFFFC107),
                              width: 5,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _switchCamera,
                        icon: const Icon(Icons.flip_camera_ios, size: 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
