from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

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

    old_cinematic = """      shutter = _durationForDenominator(
        (subjectPriority || _movementLevel > 0.8) ? 100 : 60,
      );
      iso = veryLowLight ? 640 : (lowLight ? 320 : 125);
      ev = tooBright ? -0.60 : (lowLight ? -0.15 : -0.25);
      _currentWb = 'AUTO';
"""
    new_cinematic = """      if (tooBright) {
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
  }
'''
        text = text[:start] + responsive_build + text[end + len("    );\n  }\n"):]

    path.write_text(text)
    print('Camera V2 patch applied: stronger cinematic exposure + responsive screen fit')


if __name__ == '__main__':
    main()
