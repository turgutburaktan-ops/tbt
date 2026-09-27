from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Apply one final, deterministic camera policy after scene analysis. Earlier
    # heuristics still detect light/subject/motion, but this block makes the
    # selected shooting mode the authority for ISO, shutter and EV.
    anchor = """    shutter = await _clampExposureDuration(shutter);\n\n    double minEv = -2.0;\n"""
    if anchor not in text:
        raise SystemExit('AI exposure clamp anchor not found')

    policy = r'''    String modeReason = 'Dengeli sahne';
    final moving = subjectPriority || _movementLevel > 0.8;

    switch (_selectedMode) {
      case 'Portre':
        // Portrait prioritizes a sharp face/person, natural skin exposure and
        // restrained highlights. It never uses the slow shutters of Night mode.
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(320);
          ev = -0.55;
          modeReason = 'Yüzü koru • parlak alanları bastır';
        } else if (veryLowLight) {
          iso = 800;
          shutter = _durationForDenominator(125);
          ev = -0.10;
          modeReason = 'Yüz netliği • düşük ışık';
        } else if (lowLight) {
          iso = 400;
          shutter = _durationForDenominator(160);
          ev = -0.10;
          modeReason = 'Portre netliği • ISO dengesi';
        } else {
          iso = 100;
          shutter = _durationForDenominator(200);
          ev = -0.10;
          modeReason = 'Doğal portre';
        }
        break;

      case 'Gece':
        // Night mode deliberately trades shutter speed for cleaner dark scenes
        // when the phone is steady, but protects moving people from blur.
        _currentWb = 'AUTO';
        if (tooBright) {
          iso = 100;
          shutter = _durationForDenominator(125);
          ev = -0.80;
          modeReason = 'Gece ışıklarını koru';
        } else if (veryLowLight) {
          iso = moving ? 1250 : 1000;
          shutter = moving
              ? _durationForDenominator(80)
              : _durationForDenominator(20);
          ev = -0.20;
          modeReason = moving ? 'Gece • hareket netliği' : 'Gece • daha uzun pozlama';
        } else if (lowLight) {
          iso = moving ? 800 : 640;
          shutter = moving
              ? _durationForDenominator(80)
              : _durationForDenominator(30);
          ev = -0.20;
          modeReason = moving ? 'Gece • hareket algılandı' : 'Gece • düşük gürültü';
        } else {
          iso = 320;
          shutter = _durationForDenominator(60);
          ev = -0.25;
          modeReason = 'Gece atmosferini koru';
        }
        break;

      case 'Sinematik':
        // Cinematic is highlight-first. Bright windows/neon are intentionally
        // underexposed; motion uses a faster shutter while ordinary scenes keep
        // a natural film-like cadence without fake color casts.
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
          modeReason = 'Sinematik • gölge ve hareket dengesi';
        } else {
          iso = 100;
          shutter = _durationForDenominator(moving ? 125 : 80);
          ev = -0.60;
          modeReason = 'Sinematik • filmik pozlama';
        }
        break;

      case 'Hareket':
        // Action mode is shutter priority. ISO is allowed to rise before shutter
        // drops so people, cars and sports stay sharp.
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
          modeReason = 'Hareket • düşük ışıkta hızlı shutter';
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
        // Astro only becomes a long-exposure profile when the phone is stable.
        // If motion is detected, shorten exposure to avoid a completely unusable frame.
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
        // AI Auto in Pro behaves as a neutral exposure assistant rather than a
        // stylistic preset. It still reacts to light and motion aggressively.
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
        // General photo mode aims for balanced dynamic range and a safe handheld
        // shutter instead of borrowing the cinematic/night look.
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

    text = text.replace(anchor, policy, 1)

    # Make the live HUD explicitly tell the user which selected mode drove the
    # sensor decision, rather than showing only numeric deltas.
    old_summary = """        _lastAiAppliedSummary = changes.isEmpty
            ? (tooBright
                ? 'Parlak alanlar korunuyor • pozlama düşük tutuluyor'
                : 'Sahne dengede • ayar korunuyor')
            : changes.join('  •  ');
"""
    new_summary = """        final delta = changes.isEmpty ? 'ayar korundu' : changes.join('  •  ');
        _lastAiAppliedSummary = '$_selectedMode • $modeReason • $delta';
"""
    if old_summary in text:
        text = text.replace(old_summary, new_summary, 1)
    else:
        fallback = """        _lastAiAppliedSummary = changes.isEmpty
            ? 'Sahne dengede • ayar korunuyor'
            : changes.join('  •  ');
"""
        if fallback in text:
            text = text.replace(fallback, new_summary, 1)

    path.write_text(text)
    print('Mode-aware AI camera patch applied: selected mode now owns sensor exposure policy')


if __name__ == '__main__':
    main()
