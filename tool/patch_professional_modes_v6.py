from pathlib import Path
import glob


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

    # Keep the viewfinder in the same 4:3 family as still capture (3:4 in portrait).
    # This prevents the tall arbitrary container from cropping a different part of
    # the sensor than the saved JPEG.
    old = '            Expanded(child: _buildPreview()),'
    new = '''            Expanded(\n              child: Center(\n                child: AspectRatio(\n                  aspectRatio: 3 / 4,\n                  child: _buildPreview(),\n                ),\n              ),\n            ),'''
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
        shutter = _durationForDenominator(200);
        ev = -0.10;
        zoom = 1.5;
        label = 'PORTRE • yüz/netlik';
        break;
      case 'Gece':
        iso = 500;
        shutter = _durationForDenominator(30);
        ev = -0.10;
        zoom = 1.0;
        label = 'GECE • düşük ışık';
        break;
      case 'Sinematik':
        iso = 100;
        shutter = _durationForDenominator(60);
        ev = -0.45;
        zoom = 1.15;
        label = 'SİNEMATİK • highlight/atmosfer';
        break;
      case 'Hareket':
        iso = 200;
        shutter = _durationForDenominator(500);
        ev = -0.10;
        zoom = 1.0;
        label = 'HAREKET • hızlı shutter';
        break;
      case 'Astro':
        iso = 1000;
        shutter = const Duration(milliseconds: 1000);
        ev = -0.20;
        zoom = 1.0;
        label = 'ASTRO • uzun pozlama';
        break;
      case 'Pro':
        iso = 100;
        shutter = _durationForDenominator(125);
        ev = 0.0;
        zoom = 1.0;
        label = 'PRO • nötr';
        break;
      case 'Normal':
      case 'Fotoğraf':
      default:
        iso = 100;
        shutter = _durationForDenominator(125);
        ev = -0.05;
        zoom = 1.0;
        label = 'NORMAL • dengeli';
        break;
    }

    shutter = await _clampExposureDuration(shutter);
    try {
      await _camera.setFocusMode(_subjectLocked ? iris.FocusMode.locked : iris.FocusMode.auto);
    } catch (_) {}
    try { await _camera.setZoom(zoom); } catch (_) {}
    if (_subjectLocked && _subjectPoint != null) {
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
        _currentWb = _selectedMode == 'Sinematik' ? 'LOCK' : 'AUTO';
        if (_aiAutoProEnabled) _lastAiAppliedSummary = '$label • sensörde aktif';
      });
    }
  }

'''
    text = replace_method(text, '  Future<void> _applyModeBaseSettings() async {', '  Future<void> _applyAiDecision() async {', base)

    # Replace only the final mode-policy block inserted by the mode-aware patch.
    ai_start = text.find('  Future<void> _applyAiDecision() async {')
    policy_start = text.find("    String modeReason = 'Dengeli sahne';", ai_start)
    policy_end = text.find('    shutter = await _clampExposureDuration(shutter);', policy_start)
    if policy_start < 0 or policy_end < 0:
        raise SystemExit('mode-aware AI policy block not found')

    policy = r'''    String modeReason = 'Dengeli sahne';
    final moving = subjectPriority || _movementLevel > 0.8;

    switch (_selectedMode) {
      case 'Portre':
        _currentWb = 'AUTO';
        iso = tooBright ? 100 : (veryLowLight ? 800 : (lowLight ? 400 : 100));
        shutter = _durationForDenominator(tooBright ? 320 : (moving ? 250 : (lowLight || veryLowLight ? 125 : 200)));
        ev = tooBright ? -0.40 : (veryLowLight ? 0.00 : -0.08);
        modeReason = 'Portre • yüz ve ten önceliği';
        break;

      case 'Gece':
        _currentWb = 'AUTO';
        iso = tooBright ? 100 : (veryLowLight ? (moving ? 1250 : 1000) : (lowLight ? 640 : 320));
        shutter = tooBright
            ? _durationForDenominator(100)
            : (moving ? _durationForDenominator(80) : (veryLowLight ? _durationForDenominator(20) : _durationForDenominator(30)));
        ev = tooBright ? -0.45 : -0.08;
        modeReason = moving ? 'Gece • hareket netliği' : 'Gece • gölge detayı';
        break;

      case 'Sinematik':
        // Still-photo cinematic profile: preserve practical lights/highlights,
        // avoid crushed blacks, use a modest crop, and keep exposure stable.
        _currentWb = 'LOCK';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(250);
          ev = -0.70;
          modeReason = 'Sinematik • highlight koruması';
        } else if (veryLowLight) {
          iso = moving ? 800 : 640;
          shutter = _durationForDenominator(moving ? 100 : 50);
          ev = -0.28;
          modeReason = 'Sinematik • düşük ışık atmosferi';
        } else if (lowLight) {
          iso = moving ? 500 : 320;
          shutter = _durationForDenominator(moving ? 100 : 60);
          ev = -0.35;
          modeReason = 'Sinematik • kontrollü gölgeler';
        } else {
          iso = 100;
          shutter = _durationForDenominator(moving ? 100 : 60);
          ev = -0.45;
          modeReason = 'Sinematik • filmik ton';
        }
        break;

      case 'Hareket':
        _currentWb = 'AUTO';
        iso = tooBright ? 100 : (veryLowLight ? 1600 : (lowLight ? 800 : 200));
        shutter = _durationForDenominator(tooBright ? 1000 : (veryLowLight ? 250 : (lowLight ? 320 : 500)));
        ev = tooBright ? -0.35 : -0.05;
        modeReason = 'Hareket • shutter önceliği';
        break;

      case 'Astro':
        _currentWb = 'LOCK';
        if (moving) {
          iso = 800;
          shutter = _durationForDenominator(30);
          ev = -0.10;
          modeReason = 'Astro • telefonu sabitle';
        } else {
          iso = veryLowLight ? 1600 : (lowLight ? 1200 : 600);
          shutter = veryLowLight ? const Duration(milliseconds: 1500) : const Duration(milliseconds: 1000);
          ev = -0.18;
          modeReason = 'Astro • uzun pozlama';
        }
        break;

      case 'Pro':
        _currentWb = 'AUTO';
        iso = tooBright ? 100 : (veryLowLight ? 800 : (lowLight ? 400 : 100));
        shutter = _durationForDenominator(tooBright ? 320 : (moving ? 160 : (lowLight ? 80 : 125)));
        ev = tooBright ? -0.45 : -0.05;
        modeReason = 'Pro • nötr ölçüm';
        break;

      case 'Normal':
      case 'Fotoğraf':
      default:
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(320);
          ev = -0.35;
          modeReason = 'Normal • parlak alan koruması';
        } else if (veryLowLight) {
          iso = moving ? 800 : 640;
          shutter = _durationForDenominator(moving ? 100 : 50);
          ev = 0.00;
          modeReason = 'Normal • düşük ışık';
        } else if (lowLight) {
          iso = moving ? 400 : 320;
          shutter = _durationForDenominator(moving ? 125 : 80);
          ev = -0.02;
          modeReason = 'Normal • ışık dengesi';
        } else {
          iso = 100;
          shutter = _durationForDenominator(moving ? 160 : 125);
          ev = -0.05;
          modeReason = 'Normal • doğal denge';
        }
        break;
    }

'''
    text = text[:policy_start] + policy + text[policy_end:]
    path.write_text(text)


def patch_native_preview() -> None:
    matches = sorted(glob.glob(str(Path.home() / '.pub-cache/hosted/pub.dev/iris_camera-*')))
    if not matches:
        raise SystemExit('iris_camera package cache not found')
    root = Path(matches[-1])
    path = root / 'android/src/main/kotlin/com/anies1212/iris_camera/IrisCameraPlugin.kt'
    text = path.read_text()
    marker = '                val previewView = PreviewView(context)\n'
    addition = marker + '                previewView.scaleType = PreviewView.ScaleType.FILL_CENTER\n'
    if 'previewView.scaleType = PreviewView.ScaleType.FILL_CENTER' not in text:
        if marker not in text:
            raise SystemExit('PreviewView creation marker not found')
        text = text.replace(marker, addition, 1)
    path.write_text(text)


def main() -> None:
    patch_flutter_camera()
    patch_native_preview()
    print('Professional camera V6 applied: 3:4 portrait viewport, explicit FILL_CENTER, distinct mode policies')


if __name__ == '__main__':
    main()
