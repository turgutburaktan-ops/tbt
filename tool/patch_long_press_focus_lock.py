from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    text = text.replace(
        '  Future<void> _handlePreviewTap(\n    TapDownDetails details,\n',
        '  Future<void> _handlePreviewLongPress(\n    LongPressStartDetails details,\n',
        1,
    )

    text = text.replace(
        '                  onTapDown: (details) =>\n                      _handlePreviewTap(details, constraints),\n',
        '                  onLongPressStart: (details) =>\n                      _handlePreviewLongPress(details, constraints),\n',
        1,
    )

    path.write_text(text)
    print('Focus lock changed to long press; normal taps no longer move focus.')


if __name__ == '__main__':
    main()
