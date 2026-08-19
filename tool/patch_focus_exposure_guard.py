from pathlib import Path
import re
import subprocess

# Apply the full-screen/pro/preset/lens camera upgrade first. The focus guard
# below then protects the upgraded camera from exposure jumps during tap focus.
subprocess.run(["python3", "tool/patch_camera_experience_v3.py"], check=True)

path = Path('lib/screens/camera_screen.dart')
text = path.read_text(encoding='utf-8')

new_tap = '''  Future<void> _tapFocus(TapDownDetails details, BoxConstraints c) async {
    if (_locked) return;
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    final stableEv = await _safeEv(
      _mode == 'Pro' ? _proExposureStops() + _ev : _ev,
    );
    _focusPoint = point;
    try {
      // Some camera implementations briefly meter exposure when AF is moved.
      // Keep AE automatic, but immediately restore our current safe EV so a tap
      // can never blow the preview white.
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(stableEv);
      await _camera.setFocusMode(iris.FocusMode.auto);
      await _camera.setFocus(point: point);
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(stableEv);
      await Future.delayed(const Duration(milliseconds: 140));
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(stableEv);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _tip = 'Odaklandı • pozlama korunuyor';
      });
    }
  }
'''

new_lock = '''  Future<void> _longPressLock(
    LongPressStartDetails details,
    BoxConstraints c,
  ) async {
    final point = Offset(
      (details.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
    );
    final stableEv = await _safeEv(
      _mode == 'Pro' ? _proExposureStops() + _ev : _ev,
    );
    _focusPoint = point;
    _locked = true;
    try {
      // Lock only focus. Exposure stays automatic and keeps the same safe EV.
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(stableEv);
      await _camera.setFocus(point: point);
      await _camera.setFocusMode(iris.FocusMode.locked);
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(stableEv);
      await Future.delayed(const Duration(milliseconds: 140));
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(stableEv);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _tip = 'ODAK KİLİTLİ • pozlama korunuyor • açmak için uzun bas';
      });
    }
  }
'''

text, tap_count = re.subn(
    r'  Future<void> _tapFocus\(TapDownDetails details, BoxConstraints c\) async \{.*?\n  \}\n\n  Future<void> _longPressLock',
    new_tap + '\n  Future<void> _longPressLock',
    text,
    count=1,
    flags=re.S,
)
if tap_count != 1:
    raise SystemExit('tap focus block not found')

text, lock_count = re.subn(
    r'  Future<void> _longPressLock\(\n    LongPressStartDetails details,\n    BoxConstraints c,\n  \) async \{.*?\n  \}\n\n  Future<void> _unlock',
    new_lock + '\n  Future<void> _unlock',
    text,
    count=1,
    flags=re.S,
)
if lock_count != 1:
    raise SystemExit('focus lock block not found')

path.write_text(text, encoding='utf-8')
print('Camera v3 + tap focus exposure guard applied')
