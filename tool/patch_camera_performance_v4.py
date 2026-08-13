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

    # Make sure Action mode is exposed in the camera mode rail.
    if "'Hareket'" not in text[text.find('final List<String> _modes'):text.find('@override', text.find('final List<String> _modes'))]:
        text = text.replace("    'Sinematik',\n    'Astro',", "    'Sinematik',\n    'Hareket',\n    'Astro',", 1)

    base_settings = r'''  Future<void> _applyModeBaseSettings() async {
    // V4: professional mode profiles are applied locally/native immediately.
    // Remote scene analysis only refines these values; it never owns the shutter.
    int iso;
    Duration shutter;
    double ev;
    double zoom;
    String profileLabel;

    switch (_selectedMode) {
      case 'Portre':
        iso = 100;
        shutter = _durationForDenominator(250);
        ev = -0.20;
        zoom = 1.5;
        profileLabel = 'PORTRE PRO';
        break;
      case 'Gece':
        iso = 640;
        shutter = _durationForDenominator(40);
        ev = -0.35;
        zoom = 1.0;
        profileLabel = 'GECE PRO';
        break;
      case 'Sinematik':
        iso = 100;
        shutter = _durationForDenominator(80);
        ev = -0.60;
        zoom = 1.1;
        profileLabel = 'SİNEMATİK PRO';
        break;
      case 'Hareket':
        iso = 200;
        shutter = _durationForDenominator(640);
        ev = -0.15;
        zoom = 1.0;
        profileLabel = 'HAREKET PRO';
        break;
      case 'Astro':
        iso = 1200;
        shutter = const Duration(milliseconds: 1000);
        ev = -0.25;
        zoom = 1.0;
        profileLabel = 'ASTRO PRO';
        break;
      case 'Pro':
        iso = 100;
        shutter = _durationForDenominator(125);
        ev = 0.0;
        zoom = 1.0;
        profileLabel = 'PRO NÖTR';
        break;
      case 'Fotoğraf':
      default:
        iso = 100;
        shutter = _durationForDenominator(160);
        ev = -0.12;
        zoom = 1.0;
        profileLabel = 'FOTOĞRAF PRO';
        break;
    }

    shutter = await _clampExposureDuration(shutter);

    try {
      await _camera.setFocusMode(
        _subjectLocked ? iris.FocusMode.locked : iris.FocusMode.auto,
      );
    } catch (_) {}
    try {
      await _camera.setZoom(zoom);
    } catch (_) {}

    if (_subjectLocked && _subjectPoint != null) {
      try {
        await _camera.setFocus(point: _subjectPoint!);
        await _camera.setExposurePoint(_subjectPoint!);
      } catch (_) {}
    }

    // This is the real Camera2 sensor request (AE off): ISO + shutter + EV.
    await _applyLiveManualExposure(
      iso: iso,
      shutter: shutter,
      ev: ev,
    );

    if (mounted) {
      setState(() {
        _currentIso = iso;
        _currentShutter = shutter;
        _currentEv = ev;
        _currentZoom = zoom;
        _currentFocus = _subjectLocked ? 'AF-L' : 'AF';
        _currentWb = 'AUTO';
        if (_aiAutoProEnabled) {
          _lastAiAppliedSummary = '$profileLabel • sensöre anında uygulandı';
        }
      });
    }
  }

'''

    text = replace_method(
        text,
        '  Future<void> _applyModeBaseSettings() async {',
        '  Future<void> _applyAiDecision() async {',
        base_settings,
    )

    # Shutter must not wait for remote AI or re-run sensor policy. Use the last
    # already-applied native profile. Keep only a very small collision guard if AI
    # is grabbing its tiny analysis frame at that exact instant.
    text = text.replace(
        'for (var i = 0; i < 8 && _aiFrameCaptureInProgress; i++) {\n        await Future<void>.delayed(const Duration(milliseconds: 35));\n      }',
        'for (var i = 0; i < 2 && _aiFrameCaptureInProgress; i++) {\n        await Future<void>.delayed(const Duration(milliseconds: 20));\n      }',
    )
    text = text.replace(
        '''      // Use the most recently computed mode-aware exposure immediately. If no AI\n      // result exists yet, the mode base profile is already active.\n      if (_aiAutoProEnabled && !_aiBusy) {\n        await _applyAiDecision();\n      }\n\n''',
        '''      // V4 fast shutter: the most recent mode/AI values are already on sensor.\n      // Never perform another exposure transaction on the shutter path.\n\n''',
    )

    # The fast backend returns metering guidance quickly. Avoid hammering CameraX
    # with repeated still-frame grabs while keeping the assistant responsive.
    text = text.replace(
        'DateTime.now().difference(last) < const Duration(milliseconds: 1500)',
        'DateTime.now().difference(last) < const Duration(milliseconds: 1200)',
    )
    text = text.replace(
        'Timer(const Duration(milliseconds: 250), () {',
        'Timer(const Duration(milliseconds: 180), () {',
    )

    # Extend bright-scene vocabulary so the instant meter result always triggers
    # real highlight protection, not just a text recommendation.
    bright_anchor = "combined.contains('ışığı azalt')"
    if bright_anchor in text and "combined.contains('pozlamayı azalt')" not in text:
        text = text.replace(
            bright_anchor,
            bright_anchor + " ||\n        combined.contains('pozlamayı azalt') ||\n        combined.contains('parlaklığı düşür') ||\n        combined.contains('parlak alan') ||\n        combined.contains('highlight')",
            1,
        )

    path.write_text(text)
    print('Camera performance V4 applied: instant shutter + professional native profiles')


if __name__ == '__main__':
    main()
