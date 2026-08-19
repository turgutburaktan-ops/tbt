from pathlib import Path
import re

path = Path('lib/screens/camera_screen.dart')
text = path.read_text(encoding='utf-8')


def sub(pattern: str, replacement: str, label: str, flags=re.S):
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'{label} anchor not found ({count})')


# 1) Richer preset model: presets are now photographic looks, not simple color swatches.
sub(
    r"class _FilterPreset \{.*?\n\}\n\nconst List<double> _identityMatrix",
    '''class _FilterPreset {
  final String name;
  final double contrast;
  final double saturation;
  final double brightness;
  final double gamma;
  final double hue;
  final double exposure;
  final double vignette;
  final double grain;
  final double sharpness;
  final double sepia;
  final double bleach;
  final List<double> matrix;
  final List<Color> colors;
  final Color overlay;

  const _FilterPreset({
    required this.name,
    this.contrast = 1,
    this.saturation = 1,
    this.brightness = 1,
    this.gamma = 1,
    this.hue = 0,
    this.exposure = 0,
    this.vignette = 0,
    this.grain = 0,
    this.sharpness = 0,
    this.sepia = 0,
    this.bleach = 0,
    required this.matrix,
    required this.colors,
    this.overlay = Colors.transparent,
  });
}

const List<double> _identityMatrix''',
    'preset model',
)

sub(
    r"const List<_FilterPreset> _presets = <_FilterPreset>\[.*?\n\];\n\nclass _CameraScreenState",
    '''const List<_FilterPreset> _presets = <_FilterPreset>[
  _FilterPreset(
    name: 'Natural',
    sharpness: .35,
    matrix: _identityMatrix,
    colors: [Color(0xFF5B6670), Color(0xFF1F2328)],
  ),
  _FilterPreset(
    name: 'Clean Pro',
    contrast: 1.07,
    saturation: .96,
    brightness: 1.035,
    gamma: .96,
    exposure: .04,
    sharpness: .85,
    matrix: <double>[
      1.06, 0, 0, 0, 5,
      0, 1.045, 0, 0, 4,
      0, 0, 1.035, 0, 4,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFD7E1E8), Color(0xFF4C5863)],
  ),
  _FilterPreset(
    name: 'Warm Street',
    contrast: 1.22,
    saturation: .94,
    gamma: .96,
    exposure: -.04,
    hue: -5,
    vignette: .24,
    grain: 2.4,
    sharpness: 1.0,
    matrix: <double>[
      1.18, .015, 0, 0, 7,
      .01, 1.02, 0, 0, 1,
      0, 0, .78, 0, -5,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFF2A23A), Color(0xFF402419)],
    overlay: Color(0x12FF8A00),
  ),
  _FilterPreset(
    name: 'Golden',
    contrast: 1.16,
    saturation: 1.20,
    brightness: 1.02,
    gamma: .94,
    exposure: .08,
    hue: -7,
    vignette: .17,
    grain: 1.2,
    sharpness: .75,
    matrix: <double>[
      1.22, .015, 0, 0, 9,
      .01, 1.07, 0, 0, 3,
      0, 0, .72, 0, -7,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFFFB846), Color(0xFF6E3E12)],
    overlay: Color(0x18FFB000),
  ),
  _FilterPreset(
    name: 'Cine Teal',
    contrast: 1.27,
    saturation: .82,
    brightness: .98,
    gamma: 1.02,
    exposure: -.09,
    hue: 5,
    vignette: .32,
    grain: 2.1,
    sharpness: .8,
    bleach: .12,
    matrix: <double>[
      .86, 0, .08, 0, -4,
      0, 1.04, .04, 0, 1,
      .04, .03, 1.20, 0, 7,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF23636A), Color(0xFF101A26)],
    overlay: Color(0x12005B68),
  ),
  _FilterPreset(
    name: 'Night Glow',
    contrast: 1.30,
    saturation: 1.28,
    brightness: 1.015,
    gamma: .93,
    exposure: .06,
    hue: 7,
    vignette: .29,
    grain: 2.5,
    sharpness: 1.1,
    matrix: <double>[
      .88, 0, .08, 0, -3,
      0, 1.04, .06, 0, 1,
      .06, 0, 1.26, 0, 8,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF2C2C9B), Color(0xFF071B3A)],
    overlay: Color(0x14002EAE),
  ),
  _FilterPreset(
    name: 'Forest Deep',
    contrast: 1.18,
    saturation: 1.08,
    brightness: .97,
    gamma: 1.01,
    exposure: -.06,
    hue: 3,
    vignette: .23,
    grain: 1.4,
    sharpness: .9,
    matrix: <double>[
      .82, 0, 0, 0, -3,
      .02, 1.18, .02, 0, 2,
      0, .03, .86, 0, -2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF2F7650), Color(0xFF071A12)],
    overlay: Color(0x10004E2D),
  ),
  _FilterPreset(
    name: 'Matte Film',
    contrast: .88,
    saturation: .82,
    brightness: 1.025,
    gamma: 1.08,
    exposure: .02,
    vignette: .14,
    grain: 3.6,
    sharpness: .35,
    sepia: .06,
    matrix: <double>[
      .92, 0, 0, 0, 14,
      0, .91, 0, 0, 13,
      0, 0, .90, 0, 14,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFB5B0A4), Color(0xFF4E4A44)],
    overlay: Color(0x0FFFFFFF),
  ),
  _FilterPreset(
    name: 'Portrait Soft',
    contrast: 1.02,
    saturation: .94,
    brightness: 1.055,
    gamma: .95,
    exposure: .07,
    hue: -3,
    vignette: .10,
    grain: .7,
    sharpness: .45,
    matrix: <double>[
      1.12, 0, 0, 0, 8,
      0, 1.035, 0, 0, 4,
      0, 0, .94, 0, 2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFF4B7AE), Color(0xFF8B5B58)],
    overlay: Color(0x0FFF8C80),
  ),
  _FilterPreset(
    name: 'Urban Cool',
    contrast: 1.23,
    saturation: .86,
    brightness: .985,
    gamma: 1.01,
    exposure: -.06,
    hue: 6,
    vignette: .22,
    grain: 2.0,
    sharpness: 1.05,
    matrix: <double>[
      .78, 0, .05, 0, -4,
      0, .98, .04, 0, 0,
      .05, .02, 1.24, 0, 8,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFF627A92), Color(0xFF1B2836)],
    overlay: Color(0x10004488),
  ),
  _FilterPreset(
    name: 'Vintage 90',
    contrast: 1.02,
    saturation: .76,
    brightness: 1.02,
    gamma: 1.04,
    exposure: .02,
    hue: -8,
    vignette: .30,
    grain: 4.2,
    sharpness: .4,
    sepia: .13,
    matrix: <double>[
      1.12, 0, 0, 0, 8,
      0, .97, 0, 0, 3,
      0, 0, .75, 0, -2,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFC39157), Color(0xFF553826)],
    overlay: Color(0x12A76521),
  ),
  _FilterPreset(
    name: 'Mono 400',
    contrast: 1.28,
    saturation: 0,
    brightness: 1.0,
    gamma: .98,
    exposure: -.02,
    vignette: .27,
    grain: 5.2,
    sharpness: 1.05,
    matrix: <double>[
      .2126, .7152, .0722, 0, 0,
      .2126, .7152, .0722, 0, 0,
      .2126, .7152, .0722, 0, 0,
      0, 0, 0, 1, 0,
    ],
    colors: [Color(0xFFB8B8B8), Color(0xFF202020)],
  ),
];

class _CameraScreenState''',
    'preset list',
)

# 2) Initialize on a real back wide lens instead of whatever happens to be first.
sub(
    r"  Future<void> _init\(\) async \{.*?\n  \}\n\n  Future<double> _safeEv",
    '''  Future<void> _init() async {
    try {
      _lenses = await _camera.listAvailableLenses(includeFrontCameras: true);
      if (_lenses.isNotEmpty) {
        final back = _lenses.where((l) => l.position == iris.CameraLensPosition.back).toList();
        final wide = back.where((l) => l.category == iris.CameraLensCategory.wide).toList();
        final initial = wide.isNotEmpty ? wide.first : (back.isNotEmpty ? back.first : _lenses.first);
        _lensIndex = _lenses.indexOf(initial);
        await _camera.switchLens(initial.category);
        await _camera.initialize();
        await _applyMode();
      }
    } catch (e) {
      debugPrint('camera init: $e');
    }
    if (mounted) setState(() => _initializing = false);
  }

  iris.CameraLensDescriptor? _backLens(iris.CameraLensCategory category) {
    for (final lens in _lenses) {
      if (lens.position == iris.CameraLensPosition.back && lens.category == category) {
        return lens;
      }
    }
    return null;
  }

  bool get _hasUltraWide => _backLens(iris.CameraLensCategory.ultraWide) != null;
  bool get _hasTelephoto => _backLens(iris.CameraLensCategory.telephoto) != null;

  Future<double> _safeEv''',
    'camera init',
)

# Let EV use the real device range. The previous hard -0.75/+0.55 clamp made Pro feel inert.
sub(
    r"  Future<double> _safeEv\(double wanted\) async \{.*?\n  \}\n\n  Future<void> _applyMode",
    '''  Future<double> _safeEv(double wanted) async {
    double minEv = -2;
    double maxEv = 2;
    try {
      minEv = await _camera.getMinExposureOffset();
      maxEv = await _camera.getMaxExposureOffset();
    } catch (_) {}
    return wanted.clamp(max(-3.0, minEv), min(3.0, maxEv)).toDouble();
  }

  double _proExposureStops() {
    if (_mode != 'Pro') return 0;
    final isoStops = log(max(1, _iso) / 400.0) / ln2;
    final shutterStops = log(60.0 / max(1, _shutter)) / ln2;
    return (isoStops + shutterStops).clamp(-4.0, 4.0).toDouble();
  }

  Future<void> _syncProPreviewExposure() async {
    if (_mode != 'Pro') return;
    final target = await _safeEv(_proExposureStops() + _ev);
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(target);
    } catch (_) {}
  }

  Future<void> _applyMode''',
    'safe EV',
)

# 3) 0.5x is a physical ultra-wide lens switch, not digital setZoom(0.5).
sub(
    r"  Future<void> _selectZoom\(double value\) async \{.*?\n  \}\n\n  Future<File> _capture",
    '''  Future<void> _selectZoom(double value) async {
    if (_takingPhoto) return;
    try {
      if (value < .75) {
        final ultra = _backLens(iris.CameraLensCategory.ultraWide);
        if (ultra == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bu cihaz Iris üzerinden ultra geniş lens bildirmiyor.')),
            );
          }
          return;
        }
        await _camera.switchLens(ultra.category);
        await _camera.setZoom(1.0);
        _lensIndex = _lenses.indexOf(ultra);
      } else if (value >= 1.75 && _hasTelephoto) {
        final tele = _backLens(iris.CameraLensCategory.telephoto)!;
        await _camera.switchLens(tele.category);
        await _camera.setZoom(1.0);
        _lensIndex = _lenses.indexOf(tele);
      } else {
        final wide = _backLens(iris.CameraLensCategory.wide);
        if (wide != null) {
          await _camera.switchLens(wide.category);
          _lensIndex = _lenses.indexOf(wide);
        }
        await _camera.setZoom(value >= 1.75 ? 2.0 : 1.0);
      }
      if (mounted) setState(() => _zoom = value);
      if (_mode == 'Pro') await _syncProPreviewExposure();
    } catch (e) {
      debugPrint('zoom/lens: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lens değiştirilemedi.')),
      );
    }
  }

  Future<File> _capture''',
    'physical zoom',
)

# 4) Preset rendering now includes tonal/exposure treatment, sharpness, film grain,
# vignette, optional bleach/sepia and a stronger WB shift.
sub(
    r"  Future<File> _renderPreset\(File original\) async \{.*?\n  \}\n\n  Future<void> _takePhoto",
    '''  Future<File> _renderPreset(File original) async {
    final p = _preset;
    final wbShift = ((_wbKelvin - 5200) / 1200).clamp(-2.2, 2.2).toDouble();
    final unchanged = _selectedPreset == 0 && wbShift.abs() < .12;
    if (unchanged && p.sharpness <= 0) return original;

    final output = File(
      '${Directory.systemTemp.path}/tbt_render_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final command = img.Command()
      ..decodeImageFile(original.path)
      ..bakeOrientation()
      ..adjustColor(
        contrast: p.contrast,
        saturation: p.saturation,
        brightness: p.brightness,
        gamma: p.gamma,
        exposure: p.exposure,
        hue: p.hue,
      );

    if (wbShift.abs() > .05) {
      command.colorOffset(
        red: wbShift * 9.0,
        green: wbShift * 1.2,
        blue: -wbShift * 9.0,
      );
    }
    if (p.bleach > 0) command.bleachBypass(amount: p.bleach);
    if (p.sepia > 0) command.sepia(amount: p.sepia);
    if (p.sharpness > 0) command.smooth(weight: 1.0 + p.sharpness * 7.0);
    if (p.grain > 0) command.noise(p.grain, type: img.NoiseType.gaussian);
    if (p.vignette > 0) {
      command.vignette(start: .42, end: .94, amount: p.vignette);
    }
    command.encodeJpgFile(output.path, quality: 96);
    await command.executeThread();
    if (!await output.exists()) return original;
    return output;
  }

  Future<void> _takePhoto''',
    'preset renderer',
)

# 5) Pro EV combines the manual ISO/shutter preview with compensation.
sub(
    r"  Future<void> _setEv\(double value\) async \{.*?\n  \}\n\n  Future<void> _selectZoom",
    '''  Future<void> _setEv(double value) async {
    if (mounted) setState(() => _ev = value);
    if (_mode == 'Pro') {
      await _syncProPreviewExposure();
      return;
    }
    final safe = await _safeEv(value);
    try {
      await _camera.setExposureMode(iris.ExposureMode.auto);
      await _camera.setExposureOffset(safe);
    } catch (_) {}
    if (mounted) setState(() => _ev = safe);
  }

  Future<void> _selectZoom''',
    'EV behavior',
)

# 6) Full-screen preview. Controls float over the image instead of shrinking it.
sub(
    r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  Widget _topControls\(\) \{",
    '''  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_lenses.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Kamera başlatılamadı', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _preview()),
            Positioned(left: 0, right: 0, top: 0, child: _topControls()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 54),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD9000000), Colors.black],
                    stops: [0, .28, .64],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _zoomPill(),
                    const SizedBox(height: 3),
                    _modeStrip(),
                    _presetStrip(),
                    if (_mode == 'Pro') _proPanel(),
                    _bottomBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topControls() {''',
    'full screen build',
)

# Compact glass top controls with close included.
sub(
    r"  Widget _topControls\(\) \{.*?\n  Widget _topAction",
    '''  Widget _topControls() {
    final flashIcon = _flash == iris.PhotoFlashMode.off
        ? Icons.flash_off_rounded
        : _flash == iris.PhotoFlashMode.auto
            ? Icons.flash_auto_rounded
            : Icons.flash_on_rounded;
    final timerLabel = _timerSeconds == 0 ? '0s' : '${_timerSeconds}s';

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(8, 7, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(child: _topAction(icon: Icons.close_rounded, label: '', onTap: () => Navigator.pop(context))),
          Expanded(child: _topAction(icon: flashIcon, label: 'Flaş', onTap: _cycleFlash)),
          Expanded(child: _topAction(icon: Icons.crop_rounded, label: _ratio, onTap: _cycleRatio)),
          Expanded(child: _topAction(icon: Icons.timer_outlined, label: timerLabel, onTap: _cycleTimer)),
          Expanded(child: _topAction(icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded, label: 'Izgara', onTap: () => setState(() => _showGrid = !_showGrid))),
          Expanded(child: _topAction(icon: Icons.settings_outlined, label: '', onTap: _openSettings)),
        ],
      ),
    );
  }

  Widget _topAction''',
    'top controls',
)

# Stronger WB preview matrix.
sub(
    r"  List<double> _previewMatrix\(\) \{.*?\n  \}\n\n  Widget _preview\(\) \{.*?\n  \}\n\n  Widget _glassIcon",
    '''  List<double> _previewMatrix() {
    final result = List<double>.from(_preset.matrix);
    if (_preset.name.startsWith('Mono')) return result;
    final warmth = ((_wbKelvin - 5200) / 2300).clamp(-1.0, 1.0).toDouble();
    result[0] *= 1 + warmth * .23;
    result[6] *= 1 + warmth * .035;
    result[12] *= 1 - warmth * .23;
    return result;
  }

  Widget _preview() {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix(_previewMatrix()),
            child: LayoutBuilder(
              builder: (_, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _tapFocus(d, constraints),
                onLongPressStart: (d) => _locked ? _unlock() : _longPressLock(d, constraints),
                child: const iris.IrisCameraPreview(
                  enableTapToFocus: false,
                  showFocusIndicator: false,
                ),
              ),
            ),
          ),
          if (_preset.overlay != Colors.transparent)
            IgnorePointer(child: ColoredBox(color: _preset.overlay)),
          if (_preset.vignette > 0)
            IgnorePointer(child: CustomPaint(painter: _PreviewVignettePainter((_preset.vignette * 1.7).clamp(0.0, .55).toDouble()))),
          if (_mode == 'Pro' && _proExposureStops().abs() > .25)
            IgnorePointer(
              child: ColoredBox(
                color: _proExposureStops() > 0
                    ? Colors.white.withValues(alpha: min(.20, _proExposureStops().abs() * .035))
                    : Colors.black.withValues(alpha: min(.28, _proExposureStops().abs() * .055)),
              ),
            ),
          if (_showGrid) const IgnorePointer(child: _Grid()),
          if (_focusPoint != null)
            LayoutBuilder(
              builder: (_, c) => Positioned(
                left: _focusPoint!.dx * c.maxWidth - 25,
                top: _focusPoint!.dy * c.maxHeight - 25,
                child: IgnorePointer(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFFC400), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _locked ? const Icon(Icons.lock_rounded, color: Color(0xFFFFC400), size: 15) : null,
                  ),
                ),
              ),
            ),
          if (_locked)
            Positioned(
              left: 14,
              top: 82,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: const Text('AF-L', style: TextStyle(color: Color(0xFFFFC400), fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          if (_countdown > 0)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 92, fontWeight: FontWeight.w300)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _glassIcon''',
    'preview',
)

# Zoom buttons should not offer a dead 0.5x. If the physical lens is absent,
# display it disabled rather than pretending digital 0.5 exists.
sub(
    r"  Widget _zoomPill\(\) \{.*?\n  \}\n\n  Widget _zoomButton\(double value, String label\) \{",
    '''  Widget _zoomPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomButton(.5, '0.5x', enabled: _hasUltraWide),
          _zoomButton(1, '1x'),
          _zoomButton(2, '2x'),
        ],
      ),
    );
  }

  Widget _zoomButton(double value, String label, {bool enabled = true}) {''',
    'zoom pill',
)

text = text.replace(
    "onTap: () => _selectZoom(value),\n      child: AnimatedContainer(",
    "onTap: enabled ? () => _selectZoom(value) : null,\n      child: AnimatedContainer(",
    1,
)
text = text.replace(
    "color: selected ? const Color(0xFFFFC400) : Colors.white,\n            fontWeight:",
    "color: !enabled ? Colors.white24 : selected ? const Color(0xFFFFC400) : Colors.white,\n            fontWeight:",
    1,
)

# Smaller presets: preview remains dominant.
text = text.replace("height: 96,\n      child: ListView.separated(", "height: 76,\n      child: ListView.separated(", 1)
text = text.replace("width: 82,\n              decoration: BoxDecoration(", "width: 72,\n              decoration: BoxDecoration(", 1)
text = text.replace("const Positioned(top: 13, left: 0, right: 0, child: Icon(Icons.tune_rounded, color: Colors.white70, size: 22))", "const Positioned(top: 8, left: 0, right: 0, child: Icon(Icons.tune_rounded, color: Colors.white70, size: 18))", 1)

# Pro panel is more prominent but still overlays the preview instead of shrinking it.
text = text.replace("height: 118,\n      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4)", "height: 132,\n      margin: const EdgeInsets.fromLTRB(10, 0, 10, 2)", 1)

# ISO / shutter / WB sliders update live preview immediately.
text = text.replace(
    "onChanged: (v) => setState(() => _shutter = shutterSteps[v.round()]),",
    "onChanged: (v) { setState(() => _shutter = shutterSteps[v.round()]); unawaited(_syncProPreviewExposure()); },",
    1,
)
text = text.replace(
    "onChanged: (v) => setState(() => _wbKelvin = (v / 100).round() * 100),",
    "onChanged: (v) => setState(() => _wbKelvin = (v / 100).round() * 100),",
    1,
)
text = text.replace(
    "minLabel: '-0.8',\n          maxLabel: '+0.6',\n          value: _ev,\n          min: -.75,\n          max: .55,\n          divisions: 13,",
    "minLabel: '-2.0',\n          maxLabel: '+2.0',\n          value: _ev.clamp(-2.0, 2.0).toDouble(),\n          min: -2.0,\n          max: 2.0,\n          divisions: 16,",
    1,
)
text = text.replace(
    "onChanged: (v) => setState(() => _iso = (v / 50).round() * 50),",
    "onChanged: (v) { setState(() => _iso = (v / 50).round() * 50); unawaited(_syncProPreviewExposure()); },",
    1,
)

# Slightly more compact shutter area.
text = text.replace("height: 108,\n      child: Row(", "height: 92,\n      child: Row(", 1)

# Add vignette painter once.
if 'class _PreviewVignettePainter' not in text:
    anchor = '\nclass _Grid extends StatelessWidget {'
    if anchor not in text:
        raise SystemExit('grid class anchor not found')
    painter = '''
class _PreviewVignettePainter extends CustomPainter {
  final double amount;
  const _PreviewVignettePainter(this.amount);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = RadialGradient(
      radius: .82,
      colors: <Color>[
        Colors.transparent,
        Colors.transparent,
        Colors.black.withValues(alpha: amount),
      ],
      stops: const <double>[0, .56, 1],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _PreviewVignettePainter oldDelegate) => oldDelegate.amount != amount;
}
'''
    text = text.replace(anchor, '\n' + painter + anchor, 1)

path.write_text(text, encoding='utf-8')
print('Camera experience v3 patch applied')
