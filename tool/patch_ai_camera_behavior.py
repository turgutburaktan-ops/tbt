from pathlib import Path
import glob


def patch_flutter_behavior() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Allow mode changes while an AI request is still in flight.
    if '  bool _pendingAiReanalysis = false;\n' not in text:
        text = text.replace(
            "  bool _aiBusy = false;\n",
            "  bool _aiBusy = false;\n  bool _pendingAiReanalysis = false;\n",
            1,
        )

    text = text.replace(
        "    if (mode == _selectedMode || _takingPhoto || _aiBusy) return;\n",
        "    if (mode == _selectedMode || _takingPhoto) return;\n",
        1,
    )

    old_select_tail = """    await _applyModeBaseSettings();
    if (_aiAutoProEnabled) await _analyzeSceneOnce();
  }
"""
    new_select_tail = """    await _applyModeBaseSettings();
    if (_aiAutoProEnabled) {
      if (_aiBusy) {
        _pendingAiReanalysis = true;
      } else {
        await _analyzeSceneOnce();
      }
    }
  }
"""
    if old_select_tail in text:
        text = text.replace(old_select_tail, new_select_tail, 1)

    # Ignore stale AI results if the user changed modes while the request was running.
    old_analyze_start = """  Future<void> _analyzeSceneOnce() async {
    if (!_aiAutoProEnabled || _aiBusy || _takingPhoto) return;

    setState(() {
"""
    new_analyze_start = """  Future<void> _analyzeSceneOnce() async {
    if (!_aiAutoProEnabled || _aiBusy || _takingPhoto) return;

    final analysisMode = _selectedMode;

    setState(() {
"""
    if old_analyze_start in text:
        text = text.replace(old_analyze_start, new_analyze_start, 1)

    text = text.replace(
        "      if (!mounted) return;\n\n      setState(() {\n        _aiStatus = analysis.status;\n",
        "      if (!mounted || analysisMode != _selectedMode) return;\n\n      setState(() {\n        _aiStatus = analysis.status;\n",
        1,
    )

    old_finally = """      if (mounted) setState(() => _aiBusy = false);
    }
  }
"""
    new_finally = """      if (mounted) {
        setState(() => _aiBusy = false);
        if (_pendingAiReanalysis && _aiAutoProEnabled && !_takingPhoto) {
          _pendingAiReanalysis = false;
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            if (mounted) _analyzeSceneOnce();
          });
        }
      }
    }
  }
"""
    if old_finally in text:
        text = text.replace(old_finally, new_finally, 1)

    # The AI tip was hidden behind the overlaid top toolbar. Move it below the toolbar.
    text = text.replace(
        "              Positioned(\n                top: 12,\n                left: 12,\n                right: 12,\n",
        "              Positioned(\n                top: 64,\n                left: 12,\n                right: 92,\n",
        1,
    )

    # Add a dedicated action/sports profile if it is not present yet.
    old_modes = """    'Portre',
    'Gece',
    'Sinematik',
    'Astro',
"""
    new_modes = """    'Portre',
    'Gece',
    'Sinematik',
    'Hareket',
    'Astro',
"""
    if old_modes in text and "    'Hareket',\n" not in text:
        text = text.replace(old_modes, new_modes, 1)

    # Professional base profiles. Cinematic protects highlights and keeps a filmic
    # shutter cadence; Night avoids the previous over-bright +EV look; Action gives
    # shutter priority. ISO/shutter/EV are applied to the real Android sensor by the
    # live manual exposure patch that runs before this one in CI.
    text = text.replace(
        """      case 'Portre':
        iso = 100;
        shutter = _durationForDenominator(160);
        ev = 0.15;
        zoom = 1.4;
        break;
      case 'Gece':
        iso = 800;
        shutter = _durationForDenominator(30);
        ev = 0.35;
        zoom = 1.0;
        break;
      case 'Sinematik':
        iso = 100;
        shutter = _durationForDenominator(50);
        ev = -0.10;
        zoom = 1.1;
        break;
      case 'Astro':
        iso = 800;
        shutter = const Duration(milliseconds: 500);
        ev = 0.30;
        zoom = 1.0;
        break;
""",
        """      case 'Portre':
        iso = 100;
        shutter = _durationForDenominator(160);
        ev = -0.05;
        zoom = 1.35;
        break;
      case 'Gece':
        iso = 640;
        shutter = _durationForDenominator(30);
        ev = -0.15;
        zoom = 1.0;
        break;
      case 'Sinematik':
        iso = 160;
        shutter = _durationForDenominator(50);
        ev = -0.45;
        zoom = 1.0;
        break;
      case 'Hareket':
        iso = 200;
        shutter = _durationForDenominator(500);
        ev = -0.10;
        zoom = 1.0;
        break;
      case 'Astro':
        iso = 800;
        shutter = const Duration(milliseconds: 750);
        ev = -0.10;
        zoom = 1.0;
        break;
""",
        1,
    )

    # Replace the old mode-specific AI tail with scene-aware professional behavior.
    old_ai_modes = """    if (_selectedMode == 'Portre' && subjectPriority) {
      shutter = _durationForDenominator(160);
      iso = lowLight ? max(iso, 400) : 100;
    }

    if (_selectedMode == 'Sinematik') {
      shutter = _durationForDenominator(50);
      iso = lowLight ? max(iso, 400) : 100;
    }

    if (_selectedMode == 'Gece') {
      iso = max(iso, 800);
      if (!subjectPriority && _movementLevel < 0.8) {
        shutter = _durationForDenominator(25);
      }
    }

    if (_selectedMode == 'Astro') {
      iso = max(iso, 800);
      if (_movementLevel < 0.8) {
        shutter = const Duration(milliseconds: 750);
      }
    }
"""
    new_ai_modes = """    if (_selectedMode == 'Portre' && subjectPriority) {
      shutter = _durationForDenominator(lowLight ? 125 : 200);
      iso = lowLight ? max(iso, 400) : 100;
      ev = min(ev, 0.0);
    }

    if (_selectedMode == 'Sinematik') {
      // Filmic target: protect neon/windows, keep motion natural, only raise ISO
      // when the scene actually needs it. Faster shutter is used if the phone or
      // subject is moving so a walking person stays usable instead of smearing.
      shutter = _durationForDenominator(
        (subjectPriority || _movementLevel > 0.8) ? 80 : 50,
      );
      iso = veryLowLight ? 800 : (lowLight ? 400 : 160);
      ev = tooBright ? -0.80 : (lowLight ? -0.25 : -0.45);
      _currentWb = lowLight ? 'WARM' : 'DAYLIGHT';
    }

    if (_selectedMode == 'Gece') {
      iso = veryLowLight ? 1250 : max(iso, 640);
      if (subjectPriority || _movementLevel > 0.8) {
        shutter = _durationForDenominator(60);
      } else {
        shutter = _durationForDenominator(25);
      }
      ev = tooBright ? -0.65 : -0.15;
      _currentWb = 'NIGHT';
    }

    if (_selectedMode == 'Hareket') {
      shutter = _durationForDenominator(lowLight ? 250 : 500);
      iso = veryLowLight ? 1600 : (lowLight ? 800 : max(200, iso));
      ev = tooBright ? -0.45 : -0.10;
      _currentWb = 'AUTO';
    }

    if (_selectedMode == 'Astro') {
      iso = max(iso, 800);
      if (_movementLevel < 0.8) {
        shutter = const Duration(milliseconds: 750);
      } else {
        shutter = _durationForDenominator(30);
      }
      ev = -0.10;
      _currentWb = 'COOL';
    }
"""
    if old_ai_modes in text:
        text = text.replace(old_ai_modes, new_ai_modes, 1)

    # Make the camera-switch action explicitly choose the opposite facing camera
    # instead of walking through every physical rear lens. This gives users a
    # predictable front <-> rear button even on phones with 3-4 back lenses.
    old_toggle = """  Future<void> _toggleCamera() async {
    if (_lenses.length < 2 || _takingPhoto || _aiBusy) return;

    final next = (_lensIndex + 1) % _lenses.length;
    try {
      await _camera.switchLens(_lenses[next].category);
      _lensIndex = next;
      await _applyModeBaseSettings();
      if (_aiAutoProEnabled) await _analyzeSceneOnce();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Lens değiştirme hatası: $e');
    }
  }
"""
    new_toggle = """  Future<void> _toggleCamera() async {
    if (_lenses.length < 2 || _takingPhoto) return;

    final currentCategory = _lenses[_lensIndex].category.toString().toLowerCase();
    final currentlyFront = currentCategory.contains('front');

    var next = -1;
    for (var i = 0; i < _lenses.length; i++) {
      final category = _lenses[i].category.toString().toLowerCase();
      final isFront = category.contains('front');
      if (isFront != currentlyFront) {
        next = i;
        break;
      }
    }
    if (next < 0) next = (_lensIndex + 1) % _lenses.length;

    try {
      await _camera.switchLens(_lenses[next].category);
      _lensIndex = next;

      // Front cameras commonly have no flash and narrower manual ranges.
      // Reset flash and then re-apply the selected professional profile so the
      // native exposure layer can clamp safely to that sensor's capabilities.
      final newCategory = _lenses[next].category.toString().toLowerCase();
      if (newCategory.contains('front')) _flashMode = iris.PhotoFlashMode.off;
      await _applyModeBaseSettings();

      if (_aiAutoProEnabled) {
        if (_aiBusy) {
          _pendingAiReanalysis = true;
        } else {
          await _analyzeSceneOnce();
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Ön/arka kamera değiştirme hatası: $e');
    }
  }
"""
    if old_toggle in text:
        text = text.replace(old_toggle, new_toggle, 1)

    # Live manual exposure must be applied LAST, after AF/AE metering calls.
    live_block = """    // AI live exposure: ISO + shutter + EV are applied to the preview sensor now.
    await _applyLiveManualExposure(
      iso: iso,
      shutter: shutter,
      ev: ev,
    );

"""
    if live_block in text:
        text = text.replace(live_block, '', 1)

    focus_tail = """    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentIso = iso;
"""
    live_after_focus = """    } catch (_) {}

    // Apply manual sensor exposure after focus/metering so AE cannot overwrite it.
    await _applyLiveManualExposure(
      iso: iso,
      shutter: shutter,
      ev: ev,
    );

    if (mounted) {
      setState(() {
        _currentIso = iso;
"""
    ai_pos = text.find('  Future<void> _applyAiDecision() async {')
    if ai_pos >= 0:
        tail_pos = text.find(focus_tail, ai_pos)
        if tail_pos >= 0 and 'Apply manual sensor exposure after focus/metering' not in text[ai_pos:tail_pos + 500]:
            text = text[:tail_pos] + live_after_focus + text[tail_pos + len(focus_tail):]

    path.write_text(text)


def find_iris_root() -> Path:
    matches = sorted(glob.glob(str(Path.home() / '.pub-cache/hosted/pub.dev/iris_camera-*')))
    if not matches:
        raise SystemExit('iris_camera package cache not found')
    return Path(matches[-1])


def patch_native_focus(root: Path) -> None:
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/CameraController.kt'
    text = path.read_text()

    if 'private var manualExposureActive = false' not in text:
        marker = '    private var currentExposureMode: ExposureModeNative = ExposureModeNative.AUTO\n'
        if marker not in text:
            raise SystemExit('CameraController exposure state marker not found')
        text = text.replace(marker, marker + '    private var manualExposureActive = false\n', 1)

    # setManualExposure is added by patch_live_manual_exposure.py before this script runs.
    manual_marker = """    suspend fun setManualExposure(
        exposureDurationMicros: Long,
        iso: Double,
        ev: Double,
    ) {
"""
    if manual_marker in text and 'manualExposureActive = true' not in text:
        text = text.replace(
            manual_marker,
            manual_marker + '        manualExposureActive = true\n',
            1,
        )

    old_focus_builder = """        val builder = FocusMeteringAction.Builder(meteringPoint, FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE)
"""
    new_focus_builder = """        val meteringFlags = if (manualExposureActive) {
            FocusMeteringAction.FLAG_AF
        } else {
            FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE
        }
        val builder = FocusMeteringAction.Builder(meteringPoint, meteringFlags)
"""
    if old_focus_builder in text:
        text = text.replace(old_focus_builder, new_focus_builder, 1)

    # Do not start a separate AE metering action while manual sensor exposure is active.
    old_exposure_point = """    fun setExposurePoint(point: android.graphics.PointF) {
        val controller = camera?.cameraControl ?: return
"""
    new_exposure_point = """    fun setExposurePoint(point: android.graphics.PointF) {
        if (manualExposureActive) return
        val controller = camera?.cameraControl ?: return
"""
    if old_exposure_point in text:
        text = text.replace(old_exposure_point, new_exposure_point, 1)

    path.write_text(text)


def main() -> None:
    patch_flutter_behavior()
    patch_native_focus(find_iris_root())
    print('AI camera patch applied: pro profiles + scene exposure + front/rear switch + persistent manual sensor control')


if __name__ == '__main__':
    main()
