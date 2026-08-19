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

  bool get _usingFront =>
      _activeLens?.position == iris.CameraLensPosition.front;

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

    candidates.sort((a, b) {
      double score(iris.CameraLensDescriptor lens) {
        final fov = _usableFov(lens)!;
        var s = (fov - 68.0).abs();
        if (fov > 88) s += 18;
        if (fov < 47) s += 18;
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
    if (main == null || mainFov == null) {
      for (final lens in _backLenses) {
        if (lens.category == iris.CameraLensCategory.ultraWide) return lens;
      }
      return null;
    }
    final mainId = main.id;

    final candidates = _backLenses.where((lens) {
      if (lens.id == mainId) return false;
      final fov = _usableFov(lens);
      return fov != null && fov >= mainFov * 1.18;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => _usableFov(b)!.compareTo(_usableFov(a)!));
    return candidates.first;
  }

  iris.CameraLensDescriptor? get _teleBack {
    final main = _mainBack;
    final mainFov = main == null ? null : _usableFov(main);
    if (main == null || mainFov == null) {
      for (final lens in _backLenses) {
        if (lens.category == iris.CameraLensCategory.telephoto) return lens;
      }
      return null;
    }
    final mainId = main.id;

    final candidates = _backLenses.where((lens) {
      if (lens.id == mainId) return false;
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
      // Selfie cameras must never route a zoom tap to a rear physical lens.
      // Most front cameras expose only one optical field of view, so keep
      // front capture at a truthful 1x instead of faking 0.5x / 2x.
      if (_usingFront) {
        if (target != 1) return;
        await _camera.setZoom(1);
        if (mounted) setState(() => _displayZoom = 1);
        return;
      }

      _focusPoint = null;
      _locked = false;

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

text = text.replace(
    '    final target = candidates.first;\n',
    '''    final target = targetPosition == iris.CameraLensPosition.back
        ? (_mainBack ?? candidates.first)
        : candidates.first;
''',
    1,
)

# A camera position switch invalidates any AF point from the previous sensor.
toggle_anchor = '''    try {
      _activeLens = await _switchLensDescriptor(target);
'''
if toggle_anchor in text:
    text = text.replace(
        toggle_anchor,
        '''    try {
      _focusPoint = null;
      _locked = false;
      _activeLens = await _switchLensDescriptor(target);
''',
        1,
    )

# Disable rear-only optical zoom controls while the selfie camera is active.
zoom_row_old = '''          _zoomButton(.5, '0.5', enabled: _hasUltraWide),
          _zoomButton(1, '1'),
          _zoomButton(2, '2${_hasTele ? '' : '×'}'),
'''
zoom_row_new = '''          _zoomButton(.5, '0.5', enabled: !_usingFront && _hasUltraWide),
          _zoomButton(1, '1'),
          _zoomButton(2, '2${_hasTele ? '' : '×'}', enabled: !_usingFront),
'''
if zoom_row_old not in text:
    raise SystemExit('camera zoom row not found')
text = text.replace(zoom_row_old, zoom_row_new, 1)

init_anchor = '      _lenses = await _camera.listAvailableLenses();\n'
if "TBT lens map" not in text and init_anchor in text:
    text = text.replace(
        init_anchor,
        init_anchor + "      debugPrint('TBT lens map: ${_lenses.map((l) => '${l.id}|${l.category.name}|fov=${l.fieldOfView}|f=${l.focalLength}').join(' ; ')}');\n",
        1,
    )

path.write_text(text, encoding='utf-8')
print('Camera FOV mapping + front camera zoom isolation applied')
