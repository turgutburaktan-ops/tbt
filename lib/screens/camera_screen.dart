import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

import 'legacy_camera_screen.dart';
import 'pro_filter_editor_screen.dart';

/// Primary camera entry point.
///
/// CamerAwesome is the free/open-source engine used for capture and live
/// filters. The Iris implementation remains available as a local fallback so
/// a device-specific CameraX failure never removes the camera from the app.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _openingEditor = false;
  bool _switchingToFallback = false;
  bool _capturing = false;

  Future<void> _openEditor(String imagePath) async {
    if (!mounted || _openingEditor || imagePath.isEmpty) return;
    _openingEditor = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProFilterEditorScreen(imagePath: imagePath),
        ),
      );
    } finally {
      _openingEditor = false;
    }
  }

  Future<void> _useFallback({String? reason}) async {
    if (!mounted || _switchingToFallback) return;
    _switchingToFallback = true;
    if (reason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LegacyCameraScreen()),
    );
  }

  void _onCapture(MediaCapture event) {
    if (!event.isPicture) return;
    if (event.status == MediaCaptureStatus.capturing) {
      if (mounted) setState(() => _capturing = true);
      return;
    }
    if (event.status == MediaCaptureStatus.success) {
      if (mounted) setState(() => _capturing = false);
      event.captureRequest.when(
        single: (single) {
          final path = single.file?.path;
          if (path != null) unawaited(_openEditor(path));
        },
        multiple: (multiple) {
          for (final file in multiple.fileBySensor.values) {
            final path = file?.path;
            if (path != null) {
              unawaited(_openEditor(path));
              break;
            }
          }
        },
      );
      return;
    }
    if (event.status == MediaCaptureStatus.failure) {
      if (mounted) setState(() => _capturing = false);
      unawaited(
        _useFallback(
          reason: 'Yeni kamera bu cihazda çekim yapamadı. Yedek kamera açılıyor.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraAwesomeBuilder.awesome(
            saveConfig: SaveConfig.photo(),
            // CamerAwesome's color-matrix filters decode and re-encode the
            // full JPEG on Android. Keep capture lossless and apply the richer
            // local effects in Studio instead.
            availableFilters: const [],
            progressIndicator: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            sensorConfig: SensorConfig.single(
              sensor: Sensor.position(SensorPosition.back),
              aspectRatio: CameraAspectRatios.ratio_4_3,
              flashMode: FlashMode.auto,
            ),
            onMediaCaptureEvent: _onCapture,
          ),
          if (_capturing)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(0x8A000000),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD916171B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Tam kalite hazırlanıyor',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: IconButton.filledTonal(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .58),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: TextButton.icon(
                onPressed: _useFallback,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .58),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.cameraswitch_outlined, size: 18),
                label: const Text(
                  'Yedek',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
