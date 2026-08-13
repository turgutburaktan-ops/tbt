from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Refine the cinematic profile so it stays natural rather than looking like a heavy filter.
    # Keep highlights under control, preserve realistic skin/street tones, and avoid excessive ISO.
    text = text.replace(
        """      case 'Sinematik':
        iso = 160;
        shutter = _durationForDenominator(50);
        ev = -0.45;
        zoom = 1.0;
        break;
""",
        """      case 'Sinematik':
        iso = 125;
        shutter = _durationForDenominator(60);
        ev = -0.25;
        zoom = 1.0;
        break;
""",
        1,
    )

    text = text.replace(
        """      shutter = _durationForDenominator(
        (subjectPriority || _movementLevel > 0.8) ? 80 : 50,
      );
      iso = veryLowLight ? 800 : (lowLight ? 400 : 160);
      ev = tooBright ? -0.80 : (lowLight ? -0.25 : -0.45);
      _currentWb = lowLight ? 'WARM' : 'DAYLIGHT';
""",
        """      shutter = _durationForDenominator(
        (subjectPriority || _movementLevel > 0.8) ? 100 : 60,
      );
      iso = veryLowLight ? 640 : (lowLight ? 320 : 125);
      ev = tooBright ? -0.60 : (lowLight ? -0.15 : -0.25);
      _currentWb = 'AUTO';
""",
        1,
    )

    # Night mode should still look like night: lift shadows only as much as needed.
    text = text.replace(
        "iso = veryLowLight ? 1250 : max(iso, 640);",
        "iso = veryLowLight ? 1000 : max(iso, 500);",
        1,
    )
    text = text.replace(
        "ev = tooBright ? -0.65 : -0.15;",
        "ev = tooBright ? -0.55 : -0.10;",
        1,
    )

    path.write_text(text)
    print('Cinematic realism patch applied: natural exposure, lower ISO, neutral WB')


if __name__ == '__main__':
    main()
