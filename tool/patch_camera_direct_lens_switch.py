from pathlib import Path


path = Path('lib/screens/camera_screen.dart')
text = path.read_text(encoding='utf-8')

if "package:flutter/services.dart" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
        1,
    )

helper_marker = '''  Future<void> _selectZoom(double target) async {
'''
if 'Future<iris.CameraLensDescriptor> _switchLensDescriptor' not in text:
    helper = '''  Future<iris.CameraLensDescriptor> _switchLensDescriptor(
    iris.CameraLensDescriptor descriptor,
  ) async {
    final raw = await const MethodChannel('iris_camera')
        .invokeMapMethod<String, dynamic>(
      'switchLensById',
      <String, dynamic>{'id': descriptor.id},
    );
    if (raw == null) {
      throw PlatformException(
        code: 'lens_switch_failed',
        message: 'Lens switch returned no descriptor.',
      );
    }
    return iris.CameraLensDescriptor.fromMap(
      Map<String, Object?>.from(raw),
    );
  }

'''
    if helper_marker not in text:
        raise SystemExit('camera _selectZoom marker not found')
    text = text.replace(helper_marker, helper + helper_marker, 1)

replacements = {
    '_activeLens = await _camera.switchLens(preferred.category);':
        '_activeLens = await _switchLensDescriptor(preferred);',
    '_activeLens = await _camera.switchLens(ultra.category);':
        '_activeLens = await _switchLensDescriptor(ultra);',
    '_activeLens = await _camera.switchLens(wide.category);':
        '_activeLens = await _switchLensDescriptor(wide);',
    '_activeLens = await _camera.switchLens(tele.category);':
        '_activeLens = await _switchLensDescriptor(tele);',
    '_activeLens = await _camera.switchLens(target.category);':
        '_activeLens = await _switchLensDescriptor(target);',
}

for old, new in replacements.items():
    text = text.replace(old, new)

path.write_text(text, encoding='utf-8')
print('Camera exact lens ID switching applied')
