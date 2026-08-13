from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # AI sometimes says "Pozlamayı düşür" but the old parser did not classify that
    # sentence as a bright/highlight warning. Recognize direct exposure language too.
    old_bright = """    final tooBright = combined.contains('fazla parlak') ||
        combined.contains('çok parlak') ||
        combined.contains('aşırı ışık') ||
        combined.contains('ışığı azalt');
"""
    new_bright = """    final tooBright = combined.contains('fazla parlak') ||
        combined.contains('çok parlak') ||
        combined.contains('aşırı ışık') ||
        combined.contains('ışığı azalt') ||
        combined.contains('pozlamayı düşür') ||
        combined.contains('pozlamayi dusur') ||
        combined.contains('pozlamayı azalt') ||
        combined.contains('pozlama yüksek') ||
        combined.contains('pozlama yuksek') ||
        combined.contains('patlak') ||
        combined.contains('highlight') ||
        combined.contains('parlak alan');
"""
    if old_bright in text:
        text = text.replace(old_bright, new_bright, 1)

    # Give Cinematic a darker, highlight-protecting baseline. This is still natural,
    # but it no longer leaves bright indoor windows/signage looking washed out.
    old_base = """      case 'Sinematik':
        iso = 125;
        shutter = _durationForDenominator(60);
        ev = -0.25;
        zoom = 1.0;
        break;
"""
    new_base = """      case 'Sinematik':
        iso = 100;
        shutter = _durationForDenominator(80);
        ev = -0.55;
        zoom = 1.0;
        break;
"""
    if old_base in text:
        text = text.replace(old_base, new_base, 1)

    # The previous Cinematic branch overwrote the generic bright-scene correction
    # and returned to 1/60, which is exactly why the preview stayed blown out even
    # when the AI tip said to lower exposure. Keep the strong correction here.
    old_cinematic = """      shutter = _durationForDenominator(
        (subjectPriority || _movementLevel > 0.8) ? 100 : 60,
      );
      iso = veryLowLight ? 640 : (lowLight ? 320 : 125);
      ev = tooBright ? -0.60 : (lowLight ? -0.15 : -0.25);
      _currentWb = 'AUTO';
"""
    new_cinematic = """      if (tooBright) {
        // Protect windows, screens, neon and white ceilings aggressively.
        shutter = _durationForDenominator(
          (subjectPriority || _movementLevel > 0.8) ? 200 : 160,
        );
        iso = 100;
        ev = -1.10;
      } else if (veryLowLight) {
        shutter = _durationForDenominator(60);
        iso = 640;
        ev = -0.20;
      } else if (lowLight) {
        shutter = _durationForDenominator(
          (subjectPriority || _movementLevel > 0.8) ? 100 : 80,
        );
        iso = 320;
        ev = -0.35;
      } else {
        shutter = _durationForDenominator(
          (subjectPriority || _movementLevel > 0.8) ? 125 : 80,
        );
        iso = 100;
        ev = -0.55;
      }
      _currentWb = 'AUTO';
"""
    if old_cinematic in text:
        text = text.replace(old_cinematic, new_cinematic, 1)

    # Make the AI status text match what is actually happening in a bright scene.
    old_summary = """        _lastAiAppliedSummary = changes.isEmpty
            ? 'Sahne dengede • ayar korunuyor'
            : changes.join('  •  ');
"""
    new_summary = """        _lastAiAppliedSummary = changes.isEmpty
            ? (tooBright
                ? 'Parlak alanlar korunuyor • pozlama düşük tutuluyor'
                : 'Sahne dengede • ayar korunuyor')
            : changes.join('  •  ');
"""
    if old_summary in text:
        text = text.replace(old_summary, new_summary, 1)

    # Final responsive layout. The AI HUD was enlarged from 48 to 68 px after the
    # older layout patch ran, causing a ~20 px overflow/shift on real phones.
    # Avoid height arithmetic entirely: preview takes exactly the remaining space.
    start = text.find("    return Scaffold(\n      backgroundColor: Colors.black,\n      body: SafeArea(\n        child: LayoutBuilder(")
    end_marker = "    );\n  }\n\n  Widget _buildTopBar()"
    end = text.find(end_marker, start) if start >= 0 else -1
    if start >= 0 and end >= 0:
        responsive_build = '''    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreview(),
                  Positioned(
                    top: 2,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(),
                  ),
                ],
              ),
            ),
            if (_aiAutoProEnabled) _buildCameraParams(),
            _buildModes(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
'''
        text = text[:start] + responsive_build + text[end + len("    );\n  }\n"):]

    path.write_text(text)
    print('Camera V2 patch applied: stronger cinematic exposure + responsive screen fit')


if __name__ == '__main__':
    main()
