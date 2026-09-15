from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    ai_marker = "  Future<void> _applyAiDecision() async {\n"
    ai_pos = text.find(ai_marker)
    if ai_pos < 0:
        raise SystemExit('AI decision method not found')

    anchor = "    shutter = await _clampExposureDuration(shutter);\n\n    double minEv = -2.0;\n"
    anchor_pos = text.find(anchor, ai_pos)
    if anchor_pos < 0:
        raise SystemExit('AI exposure clamp anchor not found inside _applyAiDecision')

    policy = r'''    String modeReason = 'Dengeli sahne';
    final moving = subjectPriority || _movementLevel > 0.8;

    switch (_selectedMode) {
      case 'Portre':
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(320);
          ev = -0.55;
          modeReason = 'Portre • parlak alan koruması';
        } else if (veryLowLight) {
          iso = 800;
          shutter = _durationForDenominator(125);
          ev = -0.10;
          modeReason = 'Portre • yüz netliği';
        } else if (lowLight) {
          iso = 400;
          shutter = _durationForDenominator(160);
          ev = -0.10;
          modeReason = 'Portre • düşük ışık dengesi';
        } else {
          iso = 100;
          shutter = _durationForDenominator(200);
          ev = -0.10;
          modeReason = 'Portre • doğal ten ve netlik';
        }
        break;

      case 'Gece':
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(125);
          ev = -0.80;
          modeReason = 'Gece • ışıkları koru';
        } else if (veryLowLight) {
          iso = moving ? 1250 : 1000;
          shutter = moving ? _durationForDenominator(80) : _durationForDenominator(20);
          ev = -0.20;
          modeReason = moving ? 'Gece • hareket netliği' : 'Gece • uzun pozlama';
        } else if (lowLight) {
          iso = moving ? 800 : 640;
          shutter = moving ? _durationForDenominator(80) : _durationForDenominator(30);
          ev = -0.20;
          modeReason = moving ? 'Gece • hareket algılandı' : 'Gece • düşük gürültü';
        } else {
          iso = 320;
          shutter = _durationForDenominator(60);
          ev = -0.25;
          modeReason = 'Gece • atmosferi koru';
        }
        break;

      case 'Sinematik':
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(moving ? 200 : 160);
          ev = -1.10;
          modeReason = 'Sinematik • parlak alan koruması';
        } else if (veryLowLight) {
          iso = 800;
          shutter = _durationForDenominator(moving ? 100 : 60);
          ev = -0.35;
          modeReason = 'Sinematik • gece dengesi';
        } else if (lowLight) {
          iso = 400;
          shutter = _durationForDenominator(moving ? 100 : 60);
          ev = -0.45;
          modeReason = 'Sinematik • gölge/hareket dengesi';
        } else {
          iso = 100;
          shutter = _durationForDenominator(moving ? 125 : 80);
          ev = -0.60;
          modeReason = 'Sinematik • filmik pozlama';
        }
        break;

      case 'Hareket':
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(1000);
          ev = -0.35;
          modeReason = 'Hareket • maksimum netlik';
        } else if (veryLowLight) {
          iso = 1600;
          shutter = _durationForDenominator(250);
          ev = -0.05;
          modeReason = 'Hareket • düşük ışık hızlı shutter';
        } else if (lowLight) {
          iso = 800;
          shutter = _durationForDenominator(320);
          ev = -0.10;
          modeReason = 'Hareket • shutter önceliği';
        } else {
          iso = 200;
          shutter = _durationForDenominator(500);
          ev = -0.10;
          modeReason = 'Hareket • aksiyon netliği';
        }
        break;

      case 'Astro':
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(125);
          ev = -0.80;
          modeReason = 'Astro • sahne fazla aydınlık';
        } else if (moving) {
          iso = veryLowLight ? 1600 : 1000;
          shutter = _durationForDenominator(30);
          ev = -0.10;
          modeReason = 'Astro • telefonu sabitle';
        } else if (veryLowLight) {
          iso = 1600;
          shutter = const Duration(milliseconds: 1500);
          ev = -0.20;
          modeReason = 'Astro • uzun pozlama';
        } else if (lowLight) {
          iso = 1200;
          shutter = const Duration(milliseconds: 1000);
          ev = -0.20;
          modeReason = 'Astro • yıldız pozlaması';
        } else {
          iso = 400;
          shutter = const Duration(milliseconds: 400);
          ev = -0.30;
          modeReason = 'Astro • gökyüzü ayrıntısı';
        }
        break;

      case 'Pro':
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(250);
          ev = -0.70;
          modeReason = 'Pro • highlight koruması';
        } else if (veryLowLight) {
          iso = moving ? 1000 : 800;
          shutter = _durationForDenominator(moving ? 100 : 50);
          ev = -0.05;
          modeReason = 'Pro • düşük ışık dengesi';
        } else if (lowLight) {
          iso = 400;
          shutter = _durationForDenominator(moving ? 125 : 80);
          ev = -0.10;
          modeReason = 'Pro • pozlama dengesi';
        } else {
          iso = 100;
          shutter = _durationForDenominator(125);
          ev = -0.10;
          modeReason = 'Pro • nötr profil';
        }
        break;

      case 'Fotoğraf':
      default:
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(250);
          ev = -0.70;
          modeReason = 'Fotoğraf • parlak alan koruması';
        } else if (veryLowLight) {
          iso = moving ? 1000 : 800;
          shutter = _durationForDenominator(moving ? 100 : 50);
          ev = -0.05;
          modeReason = 'Fotoğraf • düşük ışık';
        } else if (lowLight) {
          iso = moving ? 500 : 400;
          shutter = _durationForDenominator(moving ? 125 : 80);
          ev = -0.10;
          modeReason = 'Fotoğraf • ışık dengesi';
        } else {
          iso = 100;
          shutter = _durationForDenominator(moving ? 160 : 125);
          ev = -0.05;
          modeReason = 'Fotoğraf • doğal denge';
        }
        break;
    }

    shutter = await _clampExposureDuration(shutter);

    double minEv = -2.0;
'''

    text = text[:anchor_pos] + policy + text[anchor_pos + len(anchor):]

    state_marker = "        _lastAiAppliedSummary = changes.isEmpty\n"
    state_pos = text.find(state_marker, ai_pos)
    if state_pos >= 0:
        end_pos = text.find("      });", state_pos)
        if end_pos > state_pos:
            segment = text[state_pos:end_pos]
            old = """        _lastAiAppliedSummary = changes.isEmpty
            ? (tooBright
                ? 'Parlak alanlar korunuyor • pozlama düşük tutuluyor'
                : 'Sahne dengede • ayar korunuyor')
            : changes.join('  •  ');
"""
            if old not in segment:
                old = """        _lastAiAppliedSummary = changes.isEmpty
            ? 'Sahne dengede • ayar korunuyor'
            : changes.join('  •  ');
"""
            if old in segment:
                new = """        final delta = changes.isEmpty ? 'ayar korundu' : changes.join('  •  ');
        _lastAiAppliedSummary = '$_selectedMode • $modeReason • $delta';
"""
                segment = segment.replace(old, new, 1)
                text = text[:state_pos] + segment + text[end_pos:]

    path.write_text(text)
    print('Mode-aware AI camera V2 applied safely inside _applyAiDecision')


if __name__ == '__main__':
    main()
