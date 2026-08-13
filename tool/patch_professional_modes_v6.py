from pathlib import Path
import glob
import re


def replace_method(text: str, start_sig: str, next_sig: str, replacement: str) -> str:
    start = text.find(start_sig)
    if start < 0:
        raise SystemExit(f'method not found: {start_sig}')
    end = text.find(next_sig, start)
    if end < 0:
        raise SystemExit(f'next method not found: {next_sig}')
    return text[:start] + replacement + text[end:]


def patch_flutter_camera() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Five clear photographic intents, no overlapping legacy modes.
    text = re.sub(r"String _selectedMode = '[^']+';", "String _selectedMode = 'Manzara';", text, count=1)
    text = re.sub(
        r"final List<String> _modes = const \[[\s\S]*?\];",
        "final List<String> _modes = const [\n    'Portre',\n    'Manzara',\n    'Spor',\n    'Gece',\n    'Makro',\n  ];",
        text,
        count=1,
    )

    # Keep the photo viewfinder in 4:3 sensor family (3:4 in portrait). The full
    # composition is then letterboxed by native PreviewView instead of stretched or
    # silently cropped by an arbitrary tall Flutter container.
    old = '            Expanded(child: _buildPreview()),'
    new = '''            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: _buildPreview(),
                ),
              ),
            ),'''
    if old in text:
        text = text.replace(old, new, 1)

    base = r'''  Future<void> _applyModeBaseSettings() async {
    int iso;
    Duration shutter;
    double ev;
    double zoom;
    String label;

    switch (_selectedMode) {
      case 'Portre':
        iso = 100;
        shutter = _durationForDenominator(250);
        ev = -0.10;
        zoom = 1.5;
        label = 'PORTRE • YÜZ VE TEN';
        break;
      case 'Spor':
        iso = 250;
        shutter = _durationForDenominator(1000);
        ev = -0.10;
        zoom = 1.0;
        label = 'SPOR • HIZ ÖNCELİĞİ';
        break;
      case 'Gece':
        iso = 640;
        shutter = _durationForDenominator(40);
        ev = -0.20;
        zoom = 1.0;
        label = 'GECE • IŞIK KORUMA';
        break;
      case 'Makro':
        iso = 125;
        shutter = _durationForDenominator(200);
        ev = -0.05;
        zoom = 1.0;
        label = 'MAKRO • YAKIN NETLİK';
        break;
      case 'Manzara':
      default:
        iso = 100;
        shutter = _durationForDenominator(160);
        ev = -0.10;
        zoom = 1.0;
        label = 'MANZARA • DETAY VE DİNAMİK ARALIK';
        break;
    }

    shutter = await _clampExposureDuration(shutter);
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

    await _applyLiveManualExposure(iso: iso, shutter: shutter, ev: ev);

    if (mounted) {
      setState(() {
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentZoom = zoom;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
        _currentWb = 'AUTO';
        if (_aiAutoProEnabled) _lastAiAppliedSummary = '$label • sensörde aktif';
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
    final subjectPriority = _subjectLocked ||
        combined.contains('kişi') ||
        combined.contains('insan') ||
        combined.contains('yüz') ||
        _selectedMode == 'Portre';
    final moving = _movementLevel > 0.8 || _selectedMode == 'Spor';

    int iso;
    Duration shutter;
    double ev;
    String reason;

    switch (_selectedMode) {
      case 'Portre':
        iso = veryLowLight ? 800 : (lowLight ? 400 : 100);
        shutter = _durationForDenominator(veryLowLight ? 125 : (lowLight ? 160 : 250));
        ev = tooBright ? -0.45 : (lowLight ? 0.05 : -0.10);
        reason = 'Portre • yüz netliği ve ten korunuyor';
        break;
      case 'Spor':
        iso = veryLowLight ? 2000 : (lowLight ? 1250 : 250);
        shutter = _durationForDenominator(veryLowLight ? 640 : (lowLight ? 800 : 1000));
        ev = tooBright ? -0.35 : -0.10;
        reason = 'Spor • hareket donduruluyor';
        break;
      case 'Gece':
        if (moving || subjectPriority) {
          iso = veryLowLight ? 2000 : 1250;
          shutter = _durationForDenominator(80);
          reason = 'Gece • hareket netliği';
        } else {
          iso = veryLowLight ? 1250 : (lowLight ? 800 : 640);
          shutter = _durationForDenominator(veryLowLight ? 25 : 40);
          reason = 'Gece • gölge ve ışık dengesi';
        }
        ev = tooBright ? -0.55 : -0.15;
        break;
      case 'Makro':
        iso = veryLowLight ? 1000 : (lowLight ? 500 : 125);
        shutter = _durationForDenominator(veryLowLight ? 100 : (lowLight ? 125 : 200));
        ev = tooBright ? -0.35 : (lowLight ? 0.05 : -0.05);
        reason = 'Makro • yakın netlik ve mikro titreşim kontrolü';
        break;
      case 'Manzara':
      default:
        iso = veryLowLight ? 800 : (lowLight ? 400 : 100);
        shutter = _durationForDenominator(veryLowLight ? 50 : (lowLight ? 80 : 160));
        ev = tooBright ? -0.45 : (lowLight ? 0.00 : -0.10);
        reason = 'Manzara • detay ve parlak alan koruması';
        break;
    }

    shutter = await _clampExposureDuration(shutter);
    await _applyLiveManualExposure(iso: iso, shutter: shutter, ev: ev);

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
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
        _lastAiAppliedSummary = reason;
      });
    }
  }

'''
    text = replace_method(text, '  Future<void> _applyAiDecision() async {', '  Future<File> _captureToTempFile({required bool useProOverrides}) async {', ai)
    path.write_text(text)


def patch_native_preview() -> None:
    matches = sorted(glob.glob(str(Path.home() / '.pub-cache/hosted/pub.dev/iris_camera-*')))
    if not matches:
        raise SystemExit('iris_camera package cache not found')
    root = Path(matches[-1])
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/IrisCameraPlugin.kt'
    text = path.read_text()

    # Official CameraX behavior: FIT_CENTER preserves the full source aspect ratio
    # and letterboxes when the PreviewView does not match the sensor stream.
    old_fill = '                previewView.scaleType = PreviewView.ScaleType.FILL_CENTER\n'
    fit = '                previewView.scaleType = PreviewView.ScaleType.FIT_CENTER\n'
    if old_fill in text:
        text = text.replace(old_fill, fit, 1)
    elif fit not in text:
        marker = '                previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE\n'
        if marker not in text:
            raise SystemExit('PreviewView implementation marker not found')
        text = text.replace(marker, marker + fit, 1)
    path.write_text(text)


def main() -> None:
    patch_flutter_camera()
    patch_native_preview()
    print('Professional V6 camera applied: Portre, Manzara, Spor, Gece, Makro + true 3:4/FIT_CENTER preview')


if __name__ == '__main__':
    main()
