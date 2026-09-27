from pathlib import Path


def main() -> None:
    path = Path('lib/screens/camera_screen.dart')
    text = path.read_text()

    import_marker = "import 'package:image_picker/image_picker.dart';\n"
    if "package:image/image.dart" not in text:
        if import_marker not in text:
            raise SystemExit('image_picker import marker not found')
        text = text.replace(
            import_marker,
            import_marker + "import 'package:image/image.dart' as img;\n",
            1,
        )

    old = """    final bytes = await _camera.capturePhoto(options: options);\n    if (bytes.isEmpty) {\n      throw Exception('IrisCamera boş fotoğraf verisi döndürdü.');\n    }\n\n    final file = File(\n"""
    new = """    var bytes = await _camera.capturePhoto(options: options);\n    if (bytes.isEmpty) {\n      throw Exception('IrisCamera boş fotoğraf verisi döndürdü.');\n    }\n\n    // Selfie previews are mirrored on Android, while the raw JPEG normally is not.\n    // Bake EXIF orientation first and mirror the captured front-camera frame so the\n    // photo does not suddenly change direction when AI Edit opens.\n    final isFrontCamera = _lenses.isNotEmpty &&\n        _lensIndex >= 0 &&\n        _lensIndex < _lenses.length &&\n        _lenses[_lensIndex].position == iris.CameraLensPosition.front;\n    if (isFrontCamera) {\n      try {\n        final decoded = img.decodeImage(bytes);\n        if (decoded != null) {\n          final oriented = img.bakeOrientation(decoded);\n          final mirrored = img.flipHorizontal(oriented);\n          bytes = img.encodeJpg(mirrored, quality: 96);\n        }\n      } catch (e) {\n        debugPrint('Ön kamera yön düzeltme atlandı: $e');\n      }\n    }\n\n    final file = File(\n"""

    if old not in text:
        if 'Selfie previews are mirrored on Android' in text:
            print('Front camera output patch already applied')
            return
        raise SystemExit('capture bytes marker not found')

    text = text.replace(old, new, 1)
    path.write_text(text)
    print('Front camera output normalized: EXIF baked + selfie mirror preserved')


if __name__ == '__main__':
    main()
