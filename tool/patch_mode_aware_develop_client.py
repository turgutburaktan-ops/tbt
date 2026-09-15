from pathlib import Path


def patch_ai_service() -> None:
    path = Path('lib/services/ai_service.dart')
    text = path.read_text()

    old_sig = '''  static Future<AiEditResult> editPhoto({\n    required String imagePath,\n    required String action,\n    double? pointX,\n    double? pointY,\n  }) async {\n'''
    new_sig = '''  static Future<AiEditResult> editPhoto({\n    required String imagePath,\n    required String action,\n    String mode = 'Fotoğraf',\n    double? pointX,\n    double? pointY,\n  }) async {\n'''
    if old_sig in text:
        text = text.replace(old_sig, new_sig, 1)

    marker = "    request.fields['action'] = action;\n"
    if marker in text and "request.fields['mode'] = mode;" not in text:
        text = text.replace(marker, marker + "    request.fields['mode'] = mode;\n", 1)

    path.write_text(text)


def patch_edit_screen() -> None:
    path = Path('lib/screens/ai_edit_screen.dart')
    text = path.read_text()

    old_widget = '''class AiEditScreen extends StatefulWidget {\n  final String originalImagePath;\n\n  const AiEditScreen({\n    super.key,\n    required this.originalImagePath,\n  });\n'''
    new_widget = '''class AiEditScreen extends StatefulWidget {\n  final String originalImagePath;\n  final String mode;\n\n  const AiEditScreen({\n    super.key,\n    required this.originalImagePath,\n    this.mode = 'Fotoğraf',\n  });\n'''
    if old_widget in text:
        text = text.replace(old_widget, new_widget, 1)

    call = '''      final result = await AiService.editPhoto(\n        imagePath: _currentImagePath,\n        action: _actionName(action),\n'''
    repl = '''      final result = await AiService.editPhoto(\n        imagePath: _currentImagePath,\n        action: _actionName(action),\n        mode: widget.mode,\n'''
    if call in text:
        text = text.replace(call, repl, 1)

    # Make the user-visible processing state explain that the selected camera mode
    # is preserved during automatic development.
    old_auto = "        return 'Fotoğraf iyileştiriliyor...';"
    new_auto = "        return '${widget.mode} profiline göre geliştiriliyor...';"
    if old_auto in text:
        text = text.replace(old_auto, new_auto, 1)

    path.write_text(text)


def patch_camera() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    # Camera captures should keep the selected mode all the way into post processing.
    old = "builder: (_) => AiEditScreen(originalImagePath: file.path),"
    new = "builder: (_) => AiEditScreen(originalImagePath: file.path, mode: _selectedMode),"
    if old in text:
        text = text.replace(old, new)

    # Gallery photos have no capture mode; keep them neutral unless another patch has
    # already added an explicit mode.
    path.write_text(text)


def main() -> None:
    patch_ai_service()
    patch_edit_screen()
    patch_camera()
    print('Mode-aware post processing client patch applied')


if __name__ == '__main__':
    main()
