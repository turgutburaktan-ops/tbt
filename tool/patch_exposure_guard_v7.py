from pathlib import Path


def replace_method(text: str, start_sig: str, next_sig: str, replacement: str) -> str:
    start = text.find(start_sig)
    if start < 0:
        raise SystemExit(f'method not found: {start_sig}')
    end = text.find(next_sig, start)
    if end < 0:
        raise SystemExit(f'next method not found: {next_sig}')
    return text[:start] + replacement + text[end:]


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    base = r'''  Future<void> _applyModeBaseSettings() async {
    // V7: keep CameraX auto-exposure active. Smartphone lenses have a fixed,
    // very wide aperture, so DSLR-like fixed ISO/shutter recipes can clip a
    // daylight scene by several stops before AI has time to meter it.
    double ev;
    double zoom;
    int hudIso;
    Duration hudShutter;
    String label;

    switch (_selectedMode) {
      case 'Portre':
        ev = -0.15;
        zoom = 1.5;
        hudIso = 100;
        hudShutter = _durationForDenominator(250);
        label = 'PORTRE • AE + yüz önceliği';
        break;
      case 'Spor':
        ev = -0.20;
        zoom = 1.0;
        hudIso = 200;
        hudShutter = _durationForDenominator(1000);
        label = 'SPOR • AE + hareket önceliği';
        break;
      case 'Gece':
        ev = -0.10;
        zoom = 1.0;
        hudIso = 640;
        hudShutter = _durationForDenominator(40);
        label = 'GECE • AE + ışık koruma';
        break;
      case 'Makro':
        ev = -0.15;
        zoom = 1.0;
        hudIso = 125;
        hudShutter = _durationForDenominator(200);
        label = 'MAKRO • AE + yakın netlik';
        break;
      case 'Manzara':
      default:
        ev = -0.25;
        zoom = 1.0;
        hudIso = 100;
        hudShutter = _durationForDenominator(160);
        label = 'MANZARA • AE + highlight koruma';
        break;
    }

    // Explicitly return to AE so no previous Camera2 manual request can own the
    // preview. Exposure compensation then biases the phone's own scene meter.
    try { await _camera.setExposureMode(iris.ExposureMode.auto); } catch (_) {}
    try { await _camera.setExposureOffset(ev); } catch (_) {}
    try {
      await _camera.setFocusMode(_subjectLocked ? iris.FocusMode.locked : iris.FocusMode.auto);
    } catch (_) {}
    try { await _camera.setZoom(zoom); } catch (_) {}

    if (_selectedMode == 'Makro' && !_subjectLocked) {
      try {
        await _camera.setFocusMode(iris.FocusMode.auto);
        await _camera.setFocus(point: const Offset(0.5, 0.5));
        await _camera.setExposurePoint(const Offset(0.5, 0.5));
      } catch (_) {}
    } else if (_subjectLocked && _subjectPoint != null) {
      try {
        await _camera.setFocus(point: _subjectPoint!);
        await _camera.setExposurePoint(_subjectPoint!);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _currentIso = hudIso;
        _currentShutter = hudShutter;
        _currentEv = ev;
        _currentZoom = zoom;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
        _currentWb = 'AUTO';
        if (_aiAutoProEnabled) _lastAiAppliedSummary = '$label • adaptif pozlama';
      });
    }
  }

'''
    text = replace_method(text, '  Future<void> _applyModeBaseSettings() async {', '  Future<void> _applyAiDecision() async {', base)

    ai = r'''  Future<void> _applyAiDecision() async {
    final combined = [
      _aiMainTip,
      _aiLightTip,
      _aiCompositionTip,
      _aiSubjectTip,
    ].join(' ').toLowerCase();

    final lowLight = combined.contains('karanlık') ||
        combined.contains('az ışık') ||
        combined.contains('ışık düşük') ||
        combined.contains('düşük ışık');
    final veryLowLight = combined.contains('çok karanlık') ||
        combined.contains('çok düşük ışık');
    final tooBright = combined.contains('fazla parlak') ||
        combined.contains('çok parlak') ||
        combined.contains('aşırı ışık') ||
        combined.contains('ışığı azalt') ||
        combined.contains('pozlamayı azalt') ||
        combined.contains('parlaklığı düşür') ||
        combined.contains('parlak alan') ||
        combined.contains('highlight');

    double ev;
    String reason;
    switch (_selectedMode) {
      case 'Portre':
        ev = tooBright ? -0.75 : (veryLowLight ? 0.15 : (lowLight ? 0.05 : -0.15));
        reason = 'Portre • yüz/ten için adaptif AE';
        break;
      case 'Spor':
        ev = tooBright ? -0.65 : (veryLowLight ? 0.20 : (lowLight ? 0.10 : -0.20));
        reason = 'Spor • hareket için adaptif AE';
        break;
      case 'Gece':
        ev = tooBright ? -0.80 : (veryLowLight ? 0.20 : (lowLight ? 0.10 : -0.10));
        reason = 'Gece • ışıkları patlatmadan adaptif AE';
        break;
      case 'Makro':
        ev = tooBright ? -0.65 : (veryLowLight ? 0.15 : (lowLight ? 0.05 : -0.15));
        reason = 'Makro • yakın detay için adaptif AE';
        break;
      case 'Manzara':
      default:
        ev = tooBright ? -0.85 : (veryLowLight ? 0.10 : (lowLight ? 0.00 : -0.25));
        reason = 'Manzara • dinamik aralık için adaptif AE';
        break;
    }

    double minEv = -2.0;
    double maxEv = 2.0;
    try {
      minEv = await _camera.getMinExposureOffset();
      maxEv = await _camera.getMaxExposureOffset();
    } catch (_) {}
    ev = ev.clamp(minEv, maxEv).toDouble();

    try { await _camera.setExposureMode(iris.ExposureMode.auto); } catch (_) {}
    try { await _camera.setExposureOffset(ev); } catch (_) {}

    try {
      if (_subjectLocked && _subjectPoint != null) {
        await _camera.setFocus(point: _subjectPoint!);
        await _camera.setExposurePoint(_subjectPoint!);
        await _camera.setFocusMode(iris.FocusMode.locked);
      } else {
        await _camera.setFocusMode(iris.FocusMode.auto);
        await _camera.setFocus(point: const Offset(0.5, 0.5));
        await _camera.setExposurePoint(const Offset(0.5, 0.5));
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentEv = ev;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
        _lastAiAppliedSummary = reason;
      });
    }
  }

'''
    text = replace_method(text, '  Future<void> _applyAiDecision() async {', '  Future<File> _captureToTempFile({required bool useProOverrides}) async {', ai)

    capture = r'''  Future<File> _captureToTempFile({required bool useProOverrides}) async {
    // V7 safety: do not force fixed ISO/shutter on still capture. CameraX AE keeps
    // the saved JPEG aligned with the correctly-metered preview on each device.
    final options = iris.PhotoCaptureOptions(
      flashMode: _flashMode,
    );

    final bytes = await _camera.capturePhoto(options: options);
    if (bytes.isEmpty) {
      throw Exception('IrisCamera boş fotoğraf verisi döndürdü.');
    }

    final file = File(
      '${Directory.systemTemp.path}/tbt_iris_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Fotoğraf dosyası oluşturulamadı.');
    }
    return file;
  }

'''
    text = replace_method(text, '  Future<File> _captureToTempFile({required bool useProOverrides}) async {', '  Future<void> _takePhoto() async {', capture)

    # The HUD values are profile targets, not measured CaptureResult values. Mark
    # this explicitly so they are not mistaken for actual sensor telemetry.
    text = text.replace("_Param(label: 'ISO', value: '$_currentIso'),", "_Param(label: 'ISO', value: 'AUTO'),", 1)
    text = text.replace("_Param(label: 'S', value: _shutterHud),", "_Param(label: 'S', value: 'AUTO'),", 1)

    path.write_text(text)
    print('Exposure Guard V7 applied: AE-first metering, safe capture, mode-specific EV bias')


if __name__ == '__main__':
    main()
