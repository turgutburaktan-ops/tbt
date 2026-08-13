from pathlib import Path
import glob


def patch_flutter_behavior() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Allow mode changes while an AI request is still in flight.
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
    # Replace the first matching tail after _applyAiDecision only.
    ai_pos = text.find('  Future<void> _applyAiDecision() async {')
    if ai_pos >= 0:
        tail_pos = text.find(focus_tail, ai_pos)
        if tail_pos >= 0:
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
    print('AI camera behavior patch applied: mode switching + persistent manual exposure + tip placement')


if __name__ == '__main__':
    main()
