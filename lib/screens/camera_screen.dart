import 'dart:async';
import 'dart:math' as math;

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/native_photo_pipeline.dart';
import 'pro_filter_editor_screen.dart';

class _CameraPreviewLook {
  final String name;
  final AwesomeFilter filter;

  const _CameraPreviewLook(this.name, this.filter);
}

final List<_CameraPreviewLook> _cameraPreviewLooks = <_CameraPreviewLook>[
  _CameraPreviewLook('Doğal', AwesomeFilter.None),
  _CameraPreviewLook('HDR Detay', AwesomeFilter.Clarendon),
  _CameraPreviewLook('Portre Pro', AwesomeFilter.Perpetua),
  _CameraPreviewLook('Gece Temiz', AwesomeFilter.Hefe),
  _CameraPreviewLook('Soft Glow', AwesomeFilter.Reyes),
  _CameraPreviewLook('Cine Teal', AwesomeFilter.Ludwig),
  _CameraPreviewLook('Analog Film', AwesomeFilter.Gingham),
  _CameraPreviewLook('Mono Grain', AwesomeFilter.Inkwell),
];

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const MethodChannel _cameraControls =
      MethodChannel('tbt/camera_controls');

  bool _openingEditor = false;
  bool _capturing = false;
  bool _hardwareShutterPending = false;
  int _selectedLookIndex = 0;
  int _capturedLookIndex = 0;
  CameraState? _activeCameraState;

  @override
  void initState() {
    super.initState();
    _cameraControls.setMethodCallHandler(_handleCameraControl);
    unawaited(
      _cameraControls.invokeMethod<void>(
        'setActive',
        const <String, Object>{'active': true},
      ).catchError((Object error) {
        debugPrint('camera controls activation: $error');
      }),
    );
  }

  Future<Object?> _handleCameraControl(MethodCall call) async {
    if (call.method == 'volumeShutter') {
      await _takePhotoFromHardwareButton();
    }
    return null;
  }

  Future<void> _takePhotoFromHardwareButton() async {
    if (_capturing || _openingEditor || _hardwareShutterPending) return;
    final state = _activeCameraState;
    if (state is! PhotoCameraState) return;
    _hardwareShutterPending = true;
    try {
      await state.takePhoto();
    } catch (error) {
      debugPrint('volume shutter: $error');
    } finally {
      _hardwareShutterPending = false;
    }
  }

  void _rememberCameraState(CameraState state) {
    _activeCameraState = state;
  }

  Future<void> _selectLiveFilter(CameraState state, int index) async {
    if (state is! PhotoCameraState || _capturing || _openingEditor) return;
    setState(() => _selectedLookIndex = index);
    try {
      await state.setFilter(_cameraPreviewLooks[index].filter);
    } catch (error) {
      debugPrint('live camera filter: $error');
    }
  }

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
          builder: (_) => ProFilterEditorScreen(
            imagePath: preparedPath,
            initialLookIndex: _capturedLookIndex,
          ),
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
      _capturedLookIndex = _selectedLookIndex;
      if (mounted && !_capturing) setState(() => _capturing = true);
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
    _rememberCameraState(state);
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
              '4:5  •  2160×2700',
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

  Widget _middleContent(CameraState state) {
    _rememberCameraState(state);
    return Column(
      children: [
        const Spacer(),
        _LiveFilterStrip(
          state: state,
          selectedIndex: _selectedLookIndex,
          onSelected: (index) => _selectLiveFilter(state, index),
        ),
        const SizedBox(height: 8),
        _ContinuousZoomControl(state: state),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _previewOverlay(CameraState state, AnalysisPreview preview) {
    _rememberCameraState(state);
    return IgnorePointer(
      child: _LiveFilterOverlay(lookIndex: _selectedLookIndex),
    );
  }

  @override
  void dispose() {
    _cameraControls.setMethodCallHandler(null);
    unawaited(
      _cameraControls.invokeMethod<void>(
        'setActive',
        const <String, Object>{'active': false},
      ).catchError((Object error) {
        debugPrint('camera controls deactivation: $error');
      }),
    );
    super.dispose();
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
            // Volume keys are handled by MainActivity directly. CamerAwesome's
            // media-session workaround is unreliable on several Android ROMs.
            enablePhysicalButton: false,
            availableFilters:
                _cameraPreviewLooks.map((look) => look.filter).toList(),
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
            middleContentBuilder: _middleContent,
            previewDecoratorBuilder: _previewOverlay,
            onMediaCaptureEvent: _onCapture,
          ),
          if (_capturing)
            Positioned.fill(
              child: AbsorbPointer(
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

class _LiveFilterStrip extends StatelessWidget {
  final CameraState state;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _LiveFilterStrip({
    required this.state,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = state is PhotoCameraState;
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _cameraPreviewLooks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: enabled ? () => onSelected(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minWidth: 78),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xE62B2D36)
                    : const Color(0xC9131418),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF54E6D8)
                      : Colors.white24,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x4054E6D8),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    index == 0
                        ? Icons.filter_none_rounded
                        : Icons.auto_awesome_rounded,
                    color: selected ? const Color(0xFF54E6D8) : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _cameraPreviewLooks[index].name,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiveFilterOverlay extends StatelessWidget {
  final int lookIndex;

  const _LiveFilterOverlay({required this.lookIndex});

  @override
  Widget build(BuildContext context) {
    final vignette = lookIndex == 1 || lookIndex == 3 || lookIndex == 5;
    final glow = lookIndex == 2 || lookIndex == 4;
    final grain = lookIndex == 6 || lookIndex == 7;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (glow)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: .9,
                colors: [Color(0x18FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
        if (vignette)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: .82,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x52000000),
                ],
                stops: [.0, .58, 1],
              ),
            ),
          ),
        if (grain)
          const RepaintBoundary(
            child: CustomPaint(painter: _PreviewGrainPainter()),
          ),
      ],
    );
  }
}

class _PreviewGrainPainter extends CustomPainter {
  const _PreviewGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7319);
    final light = Paint()..color = const Color(0x16FFFFFF);
    final dark = Paint()..color = const Color(0x12000000);
    for (var i = 0; i < 220; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, .55, i.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
