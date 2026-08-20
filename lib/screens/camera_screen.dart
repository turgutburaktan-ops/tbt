import 'dart:async';
import 'dart:math' as math;

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

import '../services/native_photo_pipeline.dart';
import 'pro_filter_editor_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _openingEditor = false;
  bool _capturing = false;

  Future<void> _openEditor(String imagePath) async {
    if (!mounted || _openingEditor || imagePath.isEmpty) return;
    _openingEditor = true;
    try {
      // Crop, rotate and resize off the Flutter UI thread. Studio receives a
      // ready-to-share 4:5 JPEG instead of a 12/48 MP sensor bitmap.
      final preparedPath =
          await NativePhotoPipeline.prepareSharePhoto(imagePath);
      if (!mounted) return;
      setState(() => _capturing = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProFilterEditorScreen(imagePath: preparedPath),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf hazırlanamadı. Tekrar dene. ($error)'),
        ),
      );
    } finally {
      _openingEditor = false;
    }
  }

  void _onCapture(MediaCapture event) {
    if (!event.isPicture) return;
    if (event.status == MediaCaptureStatus.capturing) {
      if (mounted) setState(() => _capturing = true);
      return;
    }
    if (event.status == MediaCaptureStatus.success) {
      var opened = false;
      event.captureRequest.when(
        single: (single) {
          final path = single.file?.path;
          if (path != null) {
            opened = true;
            unawaited(_openEditor(path));
          }
        },
        multiple: (multiple) {
          for (final file in multiple.fileBySensor.values) {
            final path = file?.path;
            if (path != null) {
              opened = true;
              unawaited(_openEditor(path));
              break;
            }
          }
        },
      );
      if (!opened && mounted) setState(() => _capturing = false);
      return;
    }
    if (event.status == MediaCaptureStatus.failure) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf çekilemedi. Tekrar dene.')),
      );
    }
  }

  Widget _topActions(CameraState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: .58),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              '4:5  •  1440×1800',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          AwesomeFlashButton(state: state),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final shareFrameHeight = math.min(screen.height, screen.width * 5 / 4);
    final verticalPreviewPadding =
        math.max(0.0, (screen.height - shareFrameHeight) / 2);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraAwesomeBuilder.awesome(
            saveConfig: SaveConfig.photo(),
            enablePhysicalButton: true,
            availableFilters: const [],
            previewFit: CameraPreviewFit.cover,
            previewPadding: EdgeInsets.symmetric(
              vertical: verticalPreviewPadding,
            ),
            progressIndicator: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            sensorConfig: SensorConfig.single(
              sensor: Sensor.position(SensorPosition.back),
              // CameraX captures its high-quality 4:3 sensor image. The native
              // pipeline center-crops it to the fixed 4:5 frame shown here.
              aspectRatio: CameraAspectRatios.ratio_4_3,
              flashMode: FlashMode.auto,
            ),
            topActionsBuilder: _topActions,
            middleContentBuilder: (state) => Column(
              children: [
                const Spacer(),
                _ContinuousZoomControl(state: state),
                const SizedBox(height: 14),
              ],
            ),
            onMediaCaptureEvent: _onCapture,
          ),
          if (_capturing)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(0x66000000),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE616171B),
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
                            '4:5 fotoğraf hazırlanıyor',
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
        ],
      ),
    );
  }
}

class _ContinuousZoomControl extends StatefulWidget {
  final CameraState state;

  const _ContinuousZoomControl({required this.state});

  @override
  State<_ContinuousZoomControl> createState() =>
      _ContinuousZoomControlState();
}

class _ContinuousZoomControlState extends State<_ContinuousZoomControl> {
  double _minZoom = 1;
  double _maxZoom = 1;
  double? _localZoom;
  double? _pendingZoom;
  Timer? _zoomThrottle;

  @override
  void initState() {
    super.initState();
    _loadRange();
  }

  @override
  void didUpdateWidget(covariant _ContinuousZoomControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _loadRange();
  }

  Future<void> _loadRange() async {
    final values = await Future.wait<double?>([
      CamerawesomePlugin.getMinZoom(),
      CamerawesomePlugin.getMaxZoom(),
    ]);
    if (!mounted) return;
    setState(() {
      _minZoom = values[0] ?? 1;
      _maxZoom = math.max(_minZoom, values[1] ?? _minZoom);
    });
  }

  void _queueZoom(double value) {
    setState(() => _localZoom = value);
    _pendingZoom = value;
    _zoomThrottle ??= Timer(const Duration(milliseconds: 40), _flushZoom);
  }

  void _flushZoom() {
    _zoomThrottle = null;
    final value = _pendingZoom;
    _pendingZoom = null;
    if (value != null) {
      unawaited(
        widget.state.sensorConfig.setZoom(value).catchError((Object error) {
          debugPrint('camera zoom: $error');
        }),
      );
    }
    if (_pendingZoom != null) {
      _zoomThrottle = Timer(const Duration(milliseconds: 40), _flushZoom);
    }
  }

  void _finishZoom(double value) {
    _pendingZoom = value;
    _flushZoom();
    Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _localZoom = null);
    });
  }

  @override
  void dispose() {
    _zoomThrottle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.state.sensorConfig.zoom$,
      initialData: widget.state.sensorConfig.zoom,
      builder: (context, snapshot) {
        final normalized =
            (_localZoom ?? snapshot.data ?? 0).clamp(0.0, 1.0).toDouble();
        final displayZoom =
            _minZoom + (_maxZoom - _minZoom) * normalized;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: const Color(0xD9141519),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${displayZoom.toStringAsFixed(1)}×',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF54E6D8),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: const Color(0x3354E6D8),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: normalized,
                  min: 0,
                  max: 1,
                  onChanged: _zoomAllowed ? _queueZoom : null,
                  onChangeEnd: _zoomAllowed ? _finishZoom : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_minZoom.toStringAsFixed(1)}×',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  const Text(
                    'Kaydır veya iki parmakla yakınlaştır',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  Text(
                    '${_maxZoom.toStringAsFixed(1)}×',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _zoomAllowed => widget.state is PhotoCameraState;
}
