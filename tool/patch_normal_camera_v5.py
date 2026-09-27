from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Final V5 user-facing naming: the neutral everyday mode is Normal.
    # Earlier patches run first and may still target the old internal label.
    text = text.replace("'Fotoğraf'", "'Normal'")
    text = text.replace("FOTOĞRAF PRO", "NORMAL PRO")
    text = text.replace("Fotoğraf •", "Normal •")

    # V5: the neutral mode must not become dramatically underexposed just because
    # a few lamps/windows are clipped. The creative modes can stay more aggressive.
    # Runtime V3 previously pushed Normal/Fotoğraf bright scenes to 1/1000, EV -1.2.
    text = text.replace(
        "shutter = _durationForDenominator(1000);\n          ev = -1.20;\n          modeReason = 'Normal • parlak alan koruması';",
        "shutter = _durationForDenominator(320);\n          ev = -0.45;\n          modeReason = 'Normal • doğal highlight koruması';",
    )

    # V4 base profile should remain neutral, not stylistically dark.
    text = text.replace(
        "shutter = _durationForDenominator(160);\n        ev = -0.12;\n        zoom = 1.0;\n        profileLabel = 'NORMAL PRO';",
        "shutter = _durationForDenominator(160);\n        ev = -0.05;\n        zoom = 1.0;\n        profileLabel = 'NORMAL PRO';",
    )

    # If a prior patch left the older moderate bright-scene values, normalize those
    # too so different CI patch orderings still yield the same V5 behavior.
    text = text.replace(
        "shutter = _durationForDenominator(250);\n          ev = -0.70;\n          modeReason = 'Normal • parlak alan koruması';",
        "shutter = _durationForDenominator(320);\n          ev = -0.45;\n          modeReason = 'Normal • doğal highlight koruması';",
    )

    path.write_text(text)
    print('Normal camera V5 applied: neutral naming + balanced highlight protection')


if __name__ == '__main__':
    main()
