import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:iris_camera/iris_camera.dart' as iris;
import 'package:sensors_plus/sensors_plus.dart';

import 'pro_filter_editor_screen.dart';

class LegacyCameraScreen extends StatefulWidget {
  const LegacyCameraScreen({super.key});

  @override
  State<LegacyCameraScreen> createState() => _LegacyCameraScreenState();
}

class _ModeProfile {
  final int iso;
  final int shutterDenominator;
  final double ev;
  final String hint;

  const _ModeProfile(
    this.iso,
    this.shutterDenominator,
    this.ev,
    this.hint,
  );
}

class _LegacyCameraScreenState extends State<LegacyCameraScreen> {
  final iris.IrisCamera _camera = iris.IrisCamera();
  final ImagePicker _picker = ImagePicker();

  List<iris.CameraLensDescriptor> _lenses = [];
  iris.CameraLensDescriptor? _activeLens;
  bool _initializing = true;
  bool _takingPhoto = false;
  bool _showGrid = true;
  bool _locked = false;
  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;
  DateTime? _lastMotionUiUpdate;

  String _mode = 'Fotoğraf';
  String _tip = 'Hazır';
  int _iso = 100;
  int _shutter = 125;
  double _ev = 0;
  double _minEv = -2;
  double _maxEv = 2;
  double _displayZoom = 1;
  double _movement = 0;
  String _ratio = '4:3';
  int _timerSeconds = 0;
  int _countdown = 0;
  String _activeProControl = 'ISO';
  String? _lastShotPath;

  iris.PhotoFlashMode _flash = iris.PhotoFlashMode.auto;
  StreamSubscription<AccelerometerEvent>? _motionSub;

  static const modes = ['Fotoğraf', 'Portre', 'Gece', 'Pro'];
  static const shutterSteps = [15, 30, 60, 125, 250, 500, 1000, 2000];

  _ModeProfile get _profile {
    switch (_mode) {
      case 'Portre':
        return const _ModeProfile(100, 250, 0.0, 'Portre • odağı yüzde tut');
      case 'Gece':
        return const _ModeProfile(400, 60, 0.15, 'Gece • telefonu sabit tut');
      case 'Pro':
        return const _ModeProfile(200, 125, 0.0, 'Pro • manuel pozlama');
      default:
        return const _ModeProfile(100, 125, 0.0, 'Fotoğraf • otomatik AF/AE');
    }
  }

  bool get _hasUltraWide => _backLens(iris.CameraLensCategory.ultraWide) != null;
  bool get _hasTele => _backLens(iris.CameraLensCategory.telephoto) != null;

  iris.CameraLensDescriptor? _backLens(iris.CameraLensCategory category) {
    for (final lens in _lenses) {
      if (lens.position == iris.CameraLensPosition.back && lens.category == category) {
        return lens;
      }
    }
    return null;
  }

  iris.CameraLensDescriptor? get _wideBack =>
      _backLens(iris.CameraLensCategory.wide) ??
      _lenses.where((e) => e.position == iris.CameraLensPosition.back).firstOrNull;

  @override
  void initState() {
    super.initState();
    _init();
    _motionSub = accelerometerEventStream().listen((event) {
      final movement =
          (sqrt(event.x * event.x + event.y * event.y + event.z * event.z) - 9.81)
              .abs();
      final now = DateTime.now();
      final shouldRefresh = _lastMotionUiUpdate == null ||
          now.difference(_lastMotionUiUpdate!).inMilliseconds >= 500;
      _movement = movement;
      if (mounted && shouldRefresh) {
        _lastMotionUiUpdate = now;
        setState(() {});
      }
    });
  }

  Future<void> _init() async {
    try {
      _lenses = await _camera.listAvailableLenses();
      final preferred = _wideBack ?? (_lenses.isNotEmpty ? _lenses.first : null);
      if (preferred != null) {
        _activeLens = await _camera.switchLens(preferred.category);
        await _camera.initialize();
        try {
          _minEv = await _camera.getMinExposureOffset();
          _maxEv = await _camera.getMaxExposureOffset();
        } catch (_) {}
        await _applyMode();
      }
    } catch (e) {
      debugPrint('camera init: $e');
    }
    if (mounted) setState(() => _initializing = false);
  }

  Future<double> _safeEv(double wanted) async {
    double minEv = _minEv;
    double maxEv = _maxEv;
    try {
      minEv = await _camera.getMinExposureOffset();
      maxEv = await _camera.getMaxExposureOffset();
      _minEv = minEv;
      _maxEv = maxEv;
    } catch (_) {}
    return wanted.clamp(max(-2.0, minEv), min(2.0, maxEv)).toDouble();
  }

  Future<void> _applyMode() async {
    final p = _profile;
    _iso = p.iso;
    _shutter = p.shutterDenominator;
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
    } catch (_) {}
    try {
      await _camera.setFocusMode(
        _locked ? iris.FocusMode.locked : iris.FocusMode.auto,
      );
    } catch (_) {}
    final ev = await _safeEv(p.ev);
    try {
      await _camera.setExposureOffset(ev);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _ev = ev;
        _tip = p.hint;
      });
    }
  }

  Future<void> _tapFocus(TapDownDetails details, BoxConstraints c) async {
    if (_locked) return;
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    _focusPoint = point;

    if (_activeLens?.supportsFocus == false) {
      if (mounted) setState(() => _tip = 'Bu lens sabit odaklı');
      _scheduleFocusIndicatorHide();
      return;
    }

    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: point);
    } catch (e) {
      debugPrint('tap focus: $e');
    }
    if (mounted) setState(() => _tip = 'Odaklandı');
    _scheduleFocusIndicatorHide();
  }

  Future<void> _longPressLock(
    LongPressStartDetails details,
    BoxConstraints c,
  ) async {
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    _focusPoint = point;

    if (_activeLens?.supportsFocus == false) {
      if (mounted) setState(() => _tip = 'Bu lens sabit odaklı');
      _scheduleFocusIndicatorHide();
      return;
    }

    _focusIndicatorTimer?.cancel();
    _locked = true;
    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: point);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _camera.setFocusMode(iris.FocusMode.locked);
    } catch (e) {
      debugPrint('focus lock: $e');
    }
    if (mounted) setState(() => _tip = 'AF-L • odak kilitli');
  }

  void _scheduleFocusIndicatorHide() {
    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || _locked) return;
      setState(() {
        _focusPoint = null;
        _tip = _profile.hint;
      });
    });
  }

  Future<void> _unlock() async {
    _locked = false;
    _focusPoint = null;
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
    } catch (_) {}
    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
    } catch (_) {}
    if (mounted) setState(() => _tip = 'AF • otomatik odak');
  }

  Future<void> _selectMode(String mode) async {
    if (_takingPhoto) return;
    _focusIndicatorTimer?.cancel();
    setState(() {
      _mode = mode;
      _locked = false;
      _focusPoint = null;
      _tip = '$mode hazırlanıyor…';
      if (mode == 'Pro') _activeProControl = 'ISO';
    });
    await _applyMode();
  }

  Future<void> _setEv(double value) async {
    final safe = await _safeEv(value);
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(safe);
    } catch (_) {}
    if (mounted) setState(() => _ev = safe);
  }

  double _proPreviewEv() {
    final isoFactor = _iso / 100.0;
    final shutterFactor = 125.0 / _shutter;
    final lightFactor = max(.05, isoFactor * shutterFactor);
    final stops = log(lightFactor) / ln2;
    return stops.clamp(-2.0, 2.0).toDouble();
  }

  Future<void> _applyProPreview() async {
    if (_mode != 'Pro') return;
    await _setEv(_proPreviewEv());
  }

  Future<void> _selectZoom(double target) async {
    if (_takingPhoto) return;
    try {
      if (target == .5) {
        final ultra = _backLens(iris.CameraLensCategory.ultraWide);
        if (ultra == null) {
          _unsupportedLens('Bu telefon 0.5x ultra geniş lensi uygulamaya açmıyor.');
          return;
        }
        _activeLens = await _camera.switchLens(ultra.category);
        await _camera.setZoom(1);
      } else if (target == 1) {
        final wide = _wideBack;
        if (wide != null) {
          _activeLens = await _camera.switchLens(wide.category);
        }
        await _camera.setZoom(1);
      } else {
        final tele = _backLens(iris.CameraLensCategory.telephoto);
        if (tele != null) {
          _activeLens = await _camera.switchLens(tele.category);
          await _camera.setZoom(1);
        } else {
          final wide = _wideBack;
          if (wide != null) _activeLens = await _camera.switchLens(wide.category);
          await _camera.setZoom(2);
        }
      }
      await _applyMode();
      if (mounted) setState(() => _displayZoom = target);
    } catch (e) {
      debugPrint('lens select: $e');
      _unsupportedLens('Bu lens bu cihazda açılamadı.');
    }
  }

  void _unsupportedLens(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<File> _capture() async {
    iris.PhotoCaptureOptions options;
    if (_mode == 'Pro') {
      final shutter = _shutter.clamp(15, 2000);
      final iso = _iso.clamp(50, 1600);
      var duration = Duration(
        microseconds: max(500, (1000000 / shutter).round()),
      );
      try {
        final maxDuration = await _camera.getMaxExposureDuration();
        if (duration > maxDuration) duration = maxDuration;
      } catch (_) {}
      options = iris.PhotoCaptureOptions(
        flashMode: _flash,
        iso: iso.toDouble(),
        exposureDuration: duration,
      );
    } else {
      options = iris.PhotoCaptureOptions(
        flashMode: _mode == 'Gece' ? iris.PhotoFlashMode.off : _flash,
      );
    }

    var bytes = await _camera.capturePhoto(options: options);
    if (bytes.isEmpty) throw Exception('empty capture');

    // The Android selfie preview is mirrored while the raw JPEG generally is
    // not. Bake the same orientation into the saved photo so the result does
    // not jump horizontally when the editor opens.
    if (_activeLens?.position == iris.CameraLensPosition.front) {
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final oriented = img.bakeOrientation(decoded);
          bytes = img.encodeJpg(img.flipHorizontal(oriented), quality: 100);
        }
      } catch (e) {
        debugPrint('selfie mirror: $e');
      }
    }
    final file = File(
      '${Directory.systemTemp.path}/tbt_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return _cropToRatio(file);
  }

  Future<File> _cropToRatio(File source) async {
    if (_ratio == '4:3') return source;
    try {
      final original = img.decodeImage(await source.readAsBytes());
      if (original == null) return source;
      final target = _ratio == '1:1' ? 1.0 : 16 / 9;
      final current = original.width / original.height;
      var width = original.width;
      var height = original.height;
      if (current > target) {
        width = (original.height * target).round();
      } else {
        height = (original.width / target).round();
      }
      final x = ((original.width - width) / 2).round();
      final y = ((original.height - height) / 2).round();
      final cropped = img.copyCrop(
        original,
        x: x,
        y: y,
        width: width,
        height: height,
      );
      final output = File(
        '${Directory.systemTemp.path}/tbt_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await output.writeAsBytes(img.encodeJpg(cropped, quality: 96), flush: true);
      return output;
    } catch (_) {
      return source;
    }
  }

  Future<void> _takePhoto() async {
    if (_takingPhoto || _initializing || _countdown > 0) return;
    setState(() => _takingPhoto = true);
    try {
      if (_timerSeconds > 0) {
        for (var i = _timerSeconds; i > 0; i--) {
          if (!mounted) return;
          setState(() => _countdown = i);
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (mounted) setState(() => _countdown = 0);
      }
      final file = await _capture();
      if (!mounted) return;
      setState(() => _lastShotPath = file.path);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProFilterEditorScreen(
            imagePath: file.path,
            captureMode: _mode,
          ),
        ),
      );
      if (_mode == 'Pro') await _applyMode();
    } catch (e) {
      debugPrint('capture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf çekilemedi.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _takingPhoto = false;
          _countdown = 0;
        });
      }
    }
  }

  Future<void> _gallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (image != null && mounted) {
      setState(() => _lastShotPath = image.path);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProFilterEditorScreen(
            imagePath: image.path,
            captureMode: _mode,
          ),
        ),
      );
    }
  }

  Future<void> _toggleLens() async {
    if (_lenses.length < 2 || _takingPhoto) return;
    final currentPosition = _activeLens?.position;
    final targetPosition = currentPosition == iris.CameraLensPosition.front
        ? iris.CameraLensPosition.back
        : iris.CameraLensPosition.front;
    final candidates = _lenses.where((e) => e.position == targetPosition).toList();
    if (candidates.isEmpty) return;
    final target = candidates.first;
    try {
      _activeLens = await _camera.switchLens(target.category);
      await _camera.setZoom(1);
      await _applyMode();
      if (mounted) setState(() => _displayZoom = 1);
    } catch (e) {
      debugPrint('camera switch: $e');
    }
  }

  void _cycleFlash() {
    setState(() {
      _flash = _flash == iris.PhotoFlashMode.off
          ? iris.PhotoFlashMode.auto
          : _flash == iris.PhotoFlashMode.auto
              ? iris.PhotoFlashMode.on
              : iris.PhotoFlashMode.off;
    });
  }

  void _cycleRatio() {
    setState(() {
      _ratio = _ratio == '4:3' ? '1:1' : _ratio == '1:1' ? '16:9' : '4:3';
    });
  }

  void _cycleTimer() {
    setState(() {
      _timerSeconds = _timerSeconds == 0 ? 3 : _timerSeconds == 3 ? 10 : 0;
    });
  }

  @override
  void dispose() {
    _focusIndicatorTimer?.cancel();
    _motionSub?.cancel();
    _camera.disposeSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_lenses.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Kamera başlatılamadı',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _preview(),
          if (_showGrid) const IgnorePointer(child: _Grid()),
          IgnorePointer(child: _cropGuide()),
          _topOverlay(),
          _cameraStatusHud(),
          _focusOverlay(),
          _bottomOverlay(),
          if (_countdown > 0) _countdownOverlay(),
        ],
      ),
    );
  }

  Widget _preview() {
    return LayoutBuilder(
      builder: (_, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _tapFocus(d, constraints),
        onLongPressStart: (d) =>
            _locked ? _unlock() : _longPressLock(d, constraints),
        child: const iris.IrisCameraPreview(
          enableTapToFocus: false,
          showFocusIndicator: false,
        ),
      ),
    );
  }

  Widget _topOverlay() {
    final flashIcon = _flash == iris.PhotoFlashMode.off
        ? Icons.flash_off_rounded
        : _flash == iris.PhotoFlashMode.auto
            ? Icons.flash_auto_rounded
            : Icons.flash_on_rounded;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Color(0x00000000)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _topButton(Icons.close_rounded, '', () => Navigator.pop(context)),
              _topButton(flashIcon, 'Flaş', _cycleFlash),
              _topButton(Icons.crop_rounded, _ratio, _cycleRatio),
              _topButton(
                Icons.timer_outlined,
                _timerSeconds == 0 ? 'Timer' : '${_timerSeconds}s',
                _cycleTimer,
              ),
              _topButton(
                _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                'Grid',
                () => setState(() => _showGrid = !_showGrid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraStatusHud() {
    final steady = _movement < .55;
    final lens = _activeLens?.position == iris.CameraLensPosition.front
        ? 'Ön kamera'
        : '${_displayZoom.toStringAsFixed(_displayZoom % 1 == 0 ? 0 : 1)}x';
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 72,
      left: 14,
      right: 14,
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .54),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lens,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _tip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      steady
                          ? Icons.motion_photos_paused_rounded
                          : Icons.vibration_rounded,
                      size: 14,
                      color: steady
                          ? const Color(0xFF54E6D8)
                          : const Color(0xFFFFC400),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      steady ? 'Sabit' : 'Sabit tut',
                      style: TextStyle(
                        color: steady
                            ? const Color(0xFF54E6D8)
                            : const Color(0xFFFFC400),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minWidth: 46),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _focusOverlay() {
    if (_focusPoint == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (_, c) => Positioned(
        left: _focusPoint!.dx * c.maxWidth - 25,
        top: _focusPoint!.dy * c.maxHeight - 25,
        child: IgnorePointer(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFC400), width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _locked
                ? const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFFFC400),
                    size: 16,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _cropGuide() {
    final ratio = _ratio == '1:1' ? 1.0 : _ratio == '16:9' ? 16 / 9 : 4 / 3;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 82, 12, 190),
        child: Center(
          child: AspectRatio(
            aspectRatio: ratio,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: .7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 54, 10, 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xF5000000)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _zoomRow(),
              const SizedBox(height: 8),
              _modeRow(),
              if (_mode == 'Pro') ...[
                const SizedBox(height: 7),
                _proPanel(),
              ],
              const SizedBox(height: 10),
              _shutterRow(),
              const SizedBox(height: 4),
              Text(
                _mode == 'Pro'
                    ? 'ISO $_iso  •  1/$_shutter  •  EV ${_ev >= 0 ? '+' : ''}${_ev.toStringAsFixed(1)}'
                    : 'Stiller çekimden sonra GPU Stüdyo’da uygulanır',
                style: TextStyle(
                  color: _mode == 'Pro'
                      ? const Color(0xFFFFC400)
                      : Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoomRow() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomButton(.5, '0.5', enabled: _hasUltraWide),
          _zoomButton(1, '1'),
          _zoomButton(2, '2${_hasTele ? '' : '×'}'),
        ],
      ),
    );
  }

  Widget _zoomButton(double value, String label, {bool enabled = true}) {
    final selected = (_displayZoom - value).abs() < .05;
    return GestureDetector(
      onTap: enabled ? () => _selectZoom(value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white12 : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? Colors.white24
                : selected
                    ? const Color(0xFFFFC400)
                    : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: selected ? 15 : 13,
          ),
        ),
      ),
    );
  }

  Widget _modeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: modes.map((mode) {
        final selected = mode == _mode;
        return GestureDetector(
          onTap: () => _selectMode(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              mode,
              style: TextStyle(
                color: selected ? const Color(0xFFFFC400) : Colors.white60,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _proPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .64),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _proTab('ISO', '$_iso'),
              _proTab('S', '1/$_shutter'),
              _proTab('EV', '${_ev >= 0 ? '+' : ''}${_ev.toStringAsFixed(1)}'),
              _proTab('Odak', _locked ? 'AF-L' : 'AF'),
            ],
          ),
          SizedBox(height: 42, child: _activeProEditor()),
        ],
      ),
    );
  }

  Widget _proTab(String key, String value) {
    final selected = _activeProControl == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeProControl = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFFFFC400) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                key,
                style: const TextStyle(color: Colors.white54, fontSize: 8),
              ),
              Text(
                value,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFC400) : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeProEditor() {
    switch (_activeProControl) {
      case 'S':
        final index = shutterSteps.indexOf(_shutter).clamp(0, shutterSteps.length - 1);
        return _proSlider(
          value: index.toDouble(),
          min: 0,
          max: (shutterSteps.length - 1).toDouble(),
          divisions: shutterSteps.length - 1,
          left: '1/15',
          right: '1/2000',
          onChanged: (v) => setState(() => _shutter = shutterSteps[v.round()]),
          onChangeEnd: (_) => unawaited(_applyProPreview()),
        );
      case 'EV':
        return _proSlider(
          value: _ev.clamp(max(-2.0, _minEv), min(2.0, _maxEv)).toDouble(),
          min: max(-2.0, _minEv),
          max: min(2.0, _maxEv),
          divisions: 20,
          left: '-2',
          right: '+2',
          onChanged: (v) => setState(() => _ev = v),
          onChangeEnd: (v) => unawaited(_setEv(v)),
        );
      case 'Odak':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _unlock,
              icon: const Icon(Icons.center_focus_strong_rounded, size: 17),
              label: const Text('AF'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() => _tip = 'Kilitlemek istediğin noktaya uzun bas');
              },
              icon: const Icon(Icons.lock_outline_rounded, size: 17),
              label: Text(_locked ? 'AF-L aktif' : 'AF-L'),
            ),
          ],
        );
      default:
        return _proSlider(
          value: _iso.toDouble(),
          min: 50,
          max: 1600,
          divisions: 31,
          left: '50',
          right: '1600',
          onChanged: (v) => setState(() => _iso = (v / 50).round() * 50),
          onChangeEnd: (_) => unawaited(_applyProPreview()),
        );
    }
  }

  Widget _proSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String left,
    required String right,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            left,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 8),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFFC400),
              inactiveTrackColor: Colors.white24,
              thumbColor: const Color(0xFFFFC400),
              trackHeight: 2,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            right,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 8),
          ),
        ),
      ],
    );
  }

  Widget _shutterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        GestureDetector(
          onTap: _gallery,
          child: Container(
            width: 50,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: _lastShotPath == null
                ? const Icon(Icons.photo_library_outlined, color: Colors.white)
                : Image.file(
                    File(_lastShotPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.photo_library_outlined, color: Colors.white),
                  ),
          ),
        ),
        GestureDetector(
          onTap: _takePhoto,
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: _takingPhoto
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        GestureDetector(
          onTap: _toggleLens,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _countdownOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .40),
        child: Center(
          child: Text(
            '$_countdown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 100,
              fontWeight: FontWeight.w200,
            ),
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: const SizedBox.expand());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .22)
      ..strokeWidth = .8;
    for (final x in [size.width / 3, size.width * 2 / 3]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (final y in [size.height / 3, size.height * 2 / 3]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
