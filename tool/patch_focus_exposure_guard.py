from pathlib import Path

# The camera UI is now maintained directly in lib/screens/camera_screen.dart.
# Older builds used this step to run patch_camera_experience_v3.py first, but
# that patch targets the retired preset-card camera and must never rewrite the
# new full-screen/GPU Studio implementation.
path = Path('lib/screens/camera_screen.dart')
if not path.exists():
    raise SystemExit('camera_screen.dart not found')

text = path.read_text(encoding='utf-8')

# Safety-only compatibility cleanup. Tap-to-focus must control AF only; it must
# not re-meter exposure from a tiny point and create the old white-screen bug.
# These replacements are intentionally idempotent and do not depend on a
# particular camera UI structure.
text = text.replace(
    'await _camera.setFocus(point: _focusPoint!); await _camera.setExposurePoint(_focusPoint!);',
    'await _camera.setFocus(point: _focusPoint!);',
)
text = text.replace(
    'await _camera.setFocus(point: point);\n      await _camera.setExposurePoint(point);',
    'await _camera.setFocus(point: point);',
)
text = text.replace(
    'await _camera.setFocus(point: p);\n      await _camera.setExposurePoint(p);',
    'await _camera.setFocus(point: p);',
)

path.write_text(text, encoding='utf-8')
print('Tap focus exposure guard checked for current Pro camera')
