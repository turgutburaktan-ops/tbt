from pathlib import Path
import glob


def replace_method(text: str, signature: str, next_signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start < 0:
        raise SystemExit(f'Method start not found: {signature}')
    end = text.find(next_signature, start)
    if end < 0:
        raise SystemExit(f'Next method not found: {next_signature}')
    return text[:start] + replacement + text[end:]


def patch_camera_screen() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Only the very short frame-grab phase blocks a real shutter press. The remote
    # AI request may stay busy in the background without freezing the camera UI.
    if 'bool _aiFrameCaptureInProgress = false;' not in text:
        marker = '  bool _aiBusy = false;\n'
        text = text.replace(marker, marker + '  bool _aiFrameCaptureInProgress = false;\n', 1)

    toggle = '''  Future<void> _toggleCamera() async {
    if (_lenses.length < 2 || _takingPhoto || _initializing) return;

    final current = _lenses[_lensIndex];
    final wantFront = current.position != iris.CameraLensPosition.front;
    var next = -1;
    for (var i = 0; i < _lenses.length; i++) {
      final position = _lenses[i].position;
      if (wantFront && position == iris.CameraLensPosition.front) {
        next = i;
        break;
      }
      if (!wantFront && position == iris.CameraLensPosition.back) {
        next = i;
        break;
      }
    }
    if (next < 0) return;

    try {
      final target = _lenses[next];
      // iris_camera 1.0.6 switches only by category and therefore cannot
      // distinguish a rear-wide lens from a front-wide lens. The CI native patch
      // adds an id based switch specifically for a reliable selfie toggle.
      await _irisNative.invokeMethod<void>('switchLensById', {'id': target.id});
      _lensIndex = next;
      if (target.position == iris.CameraLensPosition.front) {
        _flashMode = iris.PhotoFlashMode.off;
      }
      _subjectLocked = false;
      _subjectPoint = null;
      await _applyModeBaseSettings();

      if (_aiAutoProEnabled) {
        _pendingAiReanalysis = true;
        if (!_aiBusy) unawaited(_analyzeSceneOnce());
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Ön/arka kamera değiştirme hatası: $e');
    }
  }

'''
    text = replace_method(
        text,
        '  Future<void> _toggleCamera() async {',
        '  Future<void> _pickFromGallery() async {',
        toggle,
    )

    take_photo = '''  Future<void> _takePhoto() async {
    if (_takingPhoto || _initializing) return;
    setState(() => _takingPhoto = true);
    _sceneChangeTimer?.cancel();

    try {
      // If AI is only grabbing a tiny analysis frame, wait briefly for that camera
      // operation to finish. Never wait for the network analysis itself.
      for (var i = 0; i < 8 && _aiFrameCaptureInProgress; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }

      // Use the most recently computed mode-aware exposure immediately. If no AI
      // result exists yet, the mode base profile is already active.
      if (_aiAutoProEnabled && !_aiBusy) {
        await _applyAiDecision();
      }

      final file = await _captureToTempFile(
        useProOverrides: _aiAutoProEnabled,
      );

      if (!mounted) return;
      final autoAction = _aiAutoProEnabled
          ? (_selectedMode == 'Gece' || _selectedMode == 'Astro'
              ? 'fix_light'
              : 'auto_enhance')
          : null;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiEditScreen(
            originalImagePath: file.path,
            initialAutoAction: autoAction,
            captureMode: _selectedMode,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Iris fotoğraf çekme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf çekilemedi. Bir kez daha dene.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _takingPhoto = false);
        if (_pendingAiReanalysis && _aiAutoProEnabled && !_aiBusy) {
          _pendingAiReanalysis = false;
          unawaited(_analyzeSceneOnce());
        }
      }
    }
  }

'''
    text = replace_method(
        text,
        '  Future<void> _takePhoto() async {',
        '  Future<void> _toggleAiAutoPro() async {',
        take_photo,
    )

    toggle_ai = '''  Future<void> _toggleAiAutoPro() async {
    final next = !_aiAutoProEnabled;
    _sceneChangeTimer?.cancel();

    setState(() {
      _aiAutoProEnabled = next;
      if (next) {
        _aiStatus = 'adjust';
        _aiMainTip = 'Mod profili uygulandı • AI sahneyi inceliyor...';
      } else {
        _aiStatus = 'idle';
        _aiMainTip = 'AI AUTO PRO kapalı.';
        _aiCompositionTip = '';
        _aiLightTip = '';
        _aiSubjectTip = '';
      }
    });

    // This is local/native and should feel instant. Network analysis continues in
    // the background so mode switching and the shutter remain responsive.
    await _applyModeBaseSettings();
    if (next) unawaited(_analyzeSceneOnce());
  }

'''
    text = replace_method(
        text,
        '  Future<void> _toggleAiAutoPro() async {',
        '  Future<void> _analyzeSceneOnce() async {',
        toggle_ai,
    )

    analyze = '''  Future<void> _analyzeSceneOnce() async {
    if (!_aiAutoProEnabled || _aiBusy || _takingPhoto) return;

    final analysisMode = _selectedMode;
    setState(() {
      _aiBusy = true;
      _aiStatus = 'adjust';
      _aiMainTip = '$analysisMode profili aktif • sahne analiz ediliyor...';
    });

    File? temp;
    try {
      _aiFrameCaptureInProgress = true;
      temp = await _captureToTempFile(useProOverrides: false);
      _aiFrameCaptureInProgress = false;

      final analysis = await AiService.analyzeLiveFrame(
        imagePath: temp.path,
        mode: _subjectModeLabel,
      );
      if (!mounted || analysisMode != _selectedMode) {
        _pendingAiReanalysis = true;
        return;
      }

      setState(() {
        _aiStatus = analysis.status;
        _aiMainTip = analysis.mainTip;
        _aiCompositionTip = analysis.compositionTip;
        _aiLightTip = analysis.lightTip;
        _aiSubjectTip = analysis.subjectTip;
      });

      // Never change sensor exposure while the user is pressing the shutter.
      if (_takingPhoto) {
        _pendingAiReanalysis = true;
      } else {
        await _applyAiDecision();
        _lastAiAnalysisAt = DateTime.now();
      }
    } catch (e) {
      _aiFrameCaptureInProgress = false;
      debugPrint('AI analiz hatası: $e');
      if (mounted && analysisMode == _selectedMode) {
        setState(() {
          _aiStatus = 'warning';
          _aiMainTip = '$analysisMode profili aktif • çevrimiçi analiz gecikti';
        });
      }
    } finally {
      _aiFrameCaptureInProgress = false;
      if (temp != null) {
        try {
          if (await temp.exists()) await temp.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _aiBusy = false);
        if (_pendingAiReanalysis && _aiAutoProEnabled && !_takingPhoto) {
          _pendingAiReanalysis = false;
          Future<void>.delayed(const Duration(milliseconds: 120), () {
            if (mounted) unawaited(_analyzeSceneOnce());
          });
        }
      }
    }
  }

'''
    text = replace_method(
        text,
        '  Future<void> _analyzeSceneOnce() async {',
        '  String get _subjectModeLabel {',
        analyze,
    )

    select_mode = '''  Future<void> _selectMode(String mode) async {
    if (mode == _selectedMode || _takingPhoto) return;

    _sceneChangeTimer?.cancel();
    setState(() {
      _selectedMode = mode;
      if (_aiAutoProEnabled) {
        _aiStatus = 'adjust';
        _aiMainTip = '$mode profili hemen uygulandı • AI inceliyor...';
      }
    });

    // Selected mode owns the sensor immediately; AI refines it asynchronously.
    await _applyModeBaseSettings();
    if (_aiAutoProEnabled) {
      _pendingAiReanalysis = true;
      if (!_aiBusy) {
        _pendingAiReanalysis = false;
        unawaited(_analyzeSceneOnce());
      }
    }
  }

'''
    text = replace_method(
        text,
        '  Future<void> _selectMode(String mode) async {',
        '  void _toggleSpotMode() {',
        select_mode,
    )

    # Faster re-analysis trigger. Remote calls remain single-flight.
    text = text.replace(
        "DateTime.now().difference(last) < const Duration(seconds: 4)",
        "DateTime.now().difference(last) < const Duration(milliseconds: 1500)",
    )
    text = text.replace(
        "Timer(const Duration(milliseconds: 900), () {",
        "Timer(const Duration(milliseconds: 250), () {",
    )

    # Stronger highlight protection. The previous values were technically changing
    # but too weak for white windows/streets, which still looked blown out.
    replacements = {
        "shutter = _durationForDenominator(320);\n          ev = -0.55;": "shutter = _durationForDenominator(640);\n          ev = -0.85;",
        "shutter = _durationForDenominator(125);\n          ev = -0.80;": "shutter = _durationForDenominator(320);\n          ev = -1.00;",
        "shutter = _durationForDenominator(moving ? 200 : 160);\n          ev = -1.10;": "shutter = _durationForDenominator(moving ? 640 : 500);\n          ev = -1.30;",
        "shutter = _durationForDenominator(1000);\n          ev = -0.35;": "shutter = _durationForDenominator(1250);\n          ev = -0.55;",
        "shutter = _durationForDenominator(250);\n          ev = -0.70;": "shutter = _durationForDenominator(1000);\n          ev = -1.20;",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)

    path.write_text(text)


def patch_ai_edit_screen() -> None:
    path = Path('lib/screens/ai_edit_screen.dart')
    text = path.read_text()

    text = text.replace(
        "  final String originalImagePath;\n\n  const AiEditScreen({\n    super.key,\n    required this.originalImagePath,\n  });",
        "  final String originalImagePath;\n  final String? initialAutoAction;\n  final String? captureMode;\n\n  const AiEditScreen({\n    super.key,\n    required this.originalImagePath,\n    this.initialAutoAction,\n    this.captureMode,\n  });",
        1,
    )

    text = text.replace(
        "    _currentImagePath = widget.originalImagePath;\n  }",
        "    _currentImagePath = widget.originalImagePath;\n    if (widget.initialAutoAction != null) {\n      WidgetsBinding.instance.addPostFrameCallback((_) {\n        if (!mounted) return;\n        final action = widget.initialAutoAction == 'fix_light'\n            ? AiEditAction.fixLight\n            : AiEditAction.autoEnhance;\n        _runEdit(action);\n      });\n    }\n  }",
        1,
    )

    # Send the selected capture mode to the server. Existing backends may simply
    # ignore this optional field, while newer ones can perform true mode-aware edits.
    text = text.replace(
        "        pointY: normalizedPoint?.dy,\n      );",
        "        pointY: normalizedPoint?.dy,\n        mode: widget.captureMode,\n      );",
        1,
    )

    path.write_text(text)


def patch_ai_service() -> None:
    path = Path('lib/services/ai_service.dart')
    text = path.read_text()
    text = text.replace(
        "    double? pointY,\n  }) async {",
        "    double? pointY,\n    String? mode,\n  }) async {",
        1,
    )
    text = text.replace(
        "    request.fields['action'] = action;\n",
        "    request.fields['action'] = action;\n    if (mode != null && mode.isNotEmpty) request.fields['mode'] = mode;\n",
        1,
    )
    path.write_text(text)


def find_iris_root() -> Path:
    matches = sorted(glob.glob(str(Path.home() / '.pub-cache/hosted/pub.dev/iris_camera-*')))
    if not matches:
        raise SystemExit('iris_camera package cache not found')
    return Path(matches[-1])


def patch_native_front_switch() -> None:
    root = find_iris_root()
    controller = root / 'android/src/main/kotlin/com/anies1212/iris_camera/CameraController.kt'
    text = controller.read_text()
    if 'suspend fun switchLensById(cameraId: String)' not in text:
        marker = '    suspend fun initialize() {\n'
        method = '''    suspend fun switchLensById(cameraId: String): CameraLensDescriptorNative {\n        val lenses = listAvailableLenses(includeFront = true)\n        val target = lenses.firstOrNull { it.id == cameraId }\n            ?: throw IllegalArgumentException("Camera id not found: $cameraId")\n        selectedLensId = target.id\n        selectedDescriptor = target\n        bindUseCases()\n        stateStreamHandler.emit(CameraLifecycleStateNative.RUNNING)\n        return target\n    }\n\n'''
        if marker not in text:
            raise SystemExit('CameraController initialize marker not found')
        text = text.replace(marker, method + marker, 1)
        controller.write_text(text)

    plugin = root / 'android/src/main/kotlin/com/anies1212/iris_camera/IrisCameraPlugin.kt'
    text = plugin.read_text()
    if '"switchLensById" ->' not in text:
        marker = '            "takePhoto" -> launchWithPermission(result) {\n'
        block = '''            "switchLensById" -> launchWithPermission(result) {\n                val cameraId = call.argument<String>("id")\n                    ?: return@launchWithPermission result.error("invalid_arguments", "Expected camera id", null)\n                val descriptor = cameraController?.switchLensById(cameraId)\n                result.success(descriptor?.toMap())\n            }\n\n'''
        if marker not in text:
            raise SystemExit('IrisCameraPlugin takePhoto marker not found')
        text = text.replace(marker, block + marker, 1)
        plugin.write_text(text)


def main() -> None:
    patch_camera_screen()
    patch_ai_edit_screen()
    patch_ai_service()
    patch_native_front_switch()
    print('Camera runtime V3 applied: id-based front camera, non-blocking AI, stronger exposure, automatic post-edit')


if __name__ == '__main__':
    main()
