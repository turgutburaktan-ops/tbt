from pathlib import Path
import re


path = Path('lib/screens/camera_screen.dart')
text = path.read_text(encoding='utf-8')

# Rebind once at the package's MAX still resolution after initialization.
init_anchor = '''        await _camera.initialize();
'''
max_line = '''        await _camera.setResolutionPreset(iris.ResolutionPreset.max);
'''
if max_line not in text:
    if init_anchor not in text:
        raise SystemExit('camera initialize anchor not found')
    text = text.replace(init_anchor, init_anchor + max_line, 1)

# Mode changes should not replay an old tap-focus point. A point belongs to the
# exact live preview geometry/lens on which it was created.
old_reapply = '''    if (_focusPoint != null) {
      try {
        await _camera.setFocus(point: _focusPoint!);
      } catch (_) {}
    }
'''
text = text.replace(old_reapply, '', 1)

# Tap focus is AF-only. Do not touch AE or EV here; the native patch also sends
# only FLAG_AF to CameraX. Fixed-focus selfie sensors simply show the indicator.
tap_pattern = re.compile(
    r'''  Future<void> _tapFocus\(TapDownDetails details, BoxConstraints c\) async \{.*?\n  \}\n\n  Future<void> _longPressLock''',
    re.S,
)
tap_replacement = r'''  Future<void> _tapFocus(TapDownDetails details, BoxConstraints c) async {
    if (_locked) return;
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    _focusPoint = point;

    if (_activeLens?.supportsFocus == false) {
      if (mounted) setState(() => _tip = 'Bu lens sabit odaklı');
      return;
    }

    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: point);
    } catch (e) {
      debugPrint('tap focus: $e');
    }
    if (mounted) setState(() => _tip = 'Odaklandı');
  }

  Future<void> _longPressLock'''
text, count = tap_pattern.subn(tap_replacement, text, count=1)
if count != 1:
    raise SystemExit('tap focus method not found')

lock_pattern = re.compile(
    r'''  Future<void> _longPressLock\(.*?\n  \}\n\n  Future<void> _unlock''',
    re.S,
)
lock_replacement = r'''  Future<void> _longPressLock(
    LongPressStartDetails details,
    BoxConstraints c,
  ) async {
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    _focusPoint = point;

    if (_activeLens?.supportsFocus == false) {
      if (mounted) setState(() => _tip = 'Bu lens sabit odaklı');
      return;
    }

    _locked = true;
    try {
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: point);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _camera.setFocusMode(iris.FocusMode.locked);
    } catch (e) {
      debugPrint('focus lock: $e');
    }
    if (mounted) setState(() => _tip = 'AF-L • odak kilitli');
  }

  Future<void> _unlock'''
text, count = lock_pattern.subn(lock_replacement, text, count=1)
if count != 1:
    raise SystemExit('long press focus method not found')

# Disabled zoom buttons must be truly inert; previously they still invoked
# _selectZoom and could jump from the front camera to a rear lens.
text = text.replace(
    '      onTap: enabled ? () => _selectZoom(value) : () => _selectZoom(value),',
    '      onTap: enabled ? () => _selectZoom(value) : null,',
    1,
)

# Avoid a second lossy JPEG step when the user selects 1:1 or 16:9 crop.
text = text.replace(
    'await output.writeAsBytes(img.encodeJpg(cropped, quality: 96), flush: true);',
    'await output.writeAsBytes(img.encodeJpg(cropped, quality: 100), flush: true);',
    1,
)

path.write_text(text, encoding='utf-8')
print('Camera runtime fidelity: MAX resolution, AF-only focus, safe front zoom applied')
