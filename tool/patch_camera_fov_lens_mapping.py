from pathlib import Path
import re


path = Path('lib/screens/camera_screen.dart')
text = path.read_text(encoding='utf-8')

helper_pattern = re.compile(
    r"  bool get _hasUltraWide =>.*?\n\n  @override\n  void initState\(\)",
    re.S,
)

helper_replacement = r'''  List<iris.CameraLensDescriptor> get _backLenses =>
      _lenses.where((e) => e.position == iris.CameraLensPosition.back).toList();

  bool _isPhysicalLens(iris.CameraLensDescriptor lens) =>
      lens.id.contains('::physical::');

  double? _usableFov(iris.CameraLensDescriptor lens) {
    final fov = lens.fieldOfView;
    if (fov == null || fov.isNaN || fov <= 5 || fov >= 170) return null;
    return fov;
  }

  iris.CameraLensDescriptor? get _mainBack {
    final candidates = _backLenses.where((lens) => _usableFov(lens) != null).toList();
    if (candidates.isEmpty) {
      for (final lens in _backLenses) {
        if (lens.category == iris.CameraLensCategory.wide) return lens;
      }
      return _backLenses.isEmpty ? null : _backLenses.first;
    }

    // A phone's 1x main camera is normally around a 60-75 degree horizontal
    // FOV. Do not trust the plugin's coarse wide/ultra/tele category alone:
    // logical multi-camera wrappers can expose misleading focal metadata.
    candidates.sort((a, b) {
      double score(iris.CameraLensDescriptor lens) {
        final fov = _usableFov(lens)!;
        var s = (fov - 68.0).abs();
        if (fov > 88) s += 18; // likely ultra-wide
        if (fov < 47) s += 18; // likely telephoto
        if (lens.category == iris.CameraLensCategory.wide) s -= 3;
        if (_isPhysicalLens(lens)) s -= 1.5;
        return s;
      }
      return score(a).compareTo(score(b));
    });
    return candidates.first;
  }

  iris.CameraLensDescriptor? get _ultraBack {
    final main = _mainBack;
    final mainFov = main == null ? null : _usableFov(main);
    if (mainFov == null) {
      for (final lens in _backLenses) {
        if (lens.category == iris.CameraLensCategory.ultraWide) return lens;
      }
      return null;
    }

    final candidates = _backLenses.where((lens) {
      if (lens.id == main.id) return false;
      final fov = _usableFov(lens);
      // Only call it 0.5x when it is materially wider than the selected 1x.
      return fov != null && fov >= mainFov * 1.18;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => _usableFov(b)!.compareTo(_usableFov(a)!));
    return candidates.first;
  }

  iris.CameraLensDescriptor? get _teleBack {
    final main = _mainBack;
    final mainFov = main == null ? null : _usableFov(main);
    if (mainFov == null) {
      for (final lens in _backLenses) {
        if (lens.category == iris.CameraLensCategory.telephoto) return lens;
      }
      return null;
    }

    final candidates = _backLenses.where((lens) {
      if (lens.id == main.id) return false;
      final fov = _usableFov(lens);
      return fov != null && fov <= mainFov * .82;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => _usableFov(a)!.compareTo(_usableFov(b)!));
    return candidates.first;
  }

  bool get _hasUltraWide => _ultraBack != null;
  bool get _hasTele => _teleBack != null;
  iris.CameraLensDescriptor? get _wideBack => _mainBack;

  @override
  void initState()'''

text, count = helper_pattern.subn(helper_replacement, text, count=1)
if count != 1:
    raise SystemExit('camera lens helper block not found')

zoom_pattern = re.compile(
    r"  Future<void> _selectZoom\(double target\) async \{.*?\n  \}\n\n  void _unsupportedLens",
    re.S,
)

zoom_replacement = r'''  Future<void> _selectZoom(double target) async {
    if (_takingPhoto) return;
    try {
      if (target == .5) {
        final ultra = _ultraBack;
        if (ultra == null) {
          _unsupportedLens(
            'Bu telefonda uygulamaya açılmış gerçek 0.5x ultra geniş lens bulunamadı.',
          );
          return;
        }
        _activeLens = await _switchLensDescriptor(ultra);
        await _camera.setZoom(1);
      } else if (target == 1) {
        final main = _mainBack;
        if (main == null) {
          _unsupportedLens('Ana arka kamera bulunamadı.');
          return;
        }
        _activeLens = await _switchLensDescriptor(main);
        await _camera.setZoom(1);
      } else {
        final main = _mainBack;
        if (main == null) {
          _unsupportedLens('Ana arka kamera bulunamadı.');
          return;
        }
        final tele = _teleBack;
        if (tele != null) {
          // Use a real tele sensor when the phone exposes one. If not, 2x is a
          // predictable digital crop on the exact same 1x main lens.
          _activeLens = await _switchLensDescriptor(tele);
          await _camera.setZoom(1);
        } else {
          _activeLens = await _switchLensDescriptor(main);
          await _camera.setZoom(2);
        }
      }
      await _applyMode();
      if (mounted) setState(() => _displayZoom = target);
    } catch (e) {
      debugPrint('lens select: $e');
      _unsupportedLens('Bu lens bu cihazda açılamadı.');
    }
  }

  void _unsupportedLens'''

text, count = zoom_pattern.subn(zoom_replacement, text, count=1)
if count != 1:
    raise SystemExit('camera zoom selection block not found')

# Returning from the selfie camera must always land on the selected 1x main
# camera, never whichever back/physical descriptor happened to be first.
text = text.replace(
    '    final target = candidates.first;\n',
    '''    final target = targetPosition == iris.CameraLensPosition.back
        ? (_mainBack ?? candidates.first)
        : candidates.first;
''',
    1,
)

# Add a concise diagnostic line. This is invaluable on vendor-specific Android
# camera stacks and has no UI impact.
init_anchor = '      _lenses = await _camera.listAvailableLenses();\n'
if "TBT lens map" not in text and init_anchor in text:
    text = text.replace(
        init_anchor,
        init_anchor + "      debugPrint('TBT lens map: ${_lenses.map((l) => '${l.id}|${l.category.name}|fov=${l.fieldOfView}|f=${l.focalLength}').join(' ; ')}');\n",
        1,
    )

path.write_text(text, encoding='utf-8')
print('Camera FOV-based 0.5x / 1x / tele mapping applied')
