import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_filters/flutter_image_filters.dart';
import 'package:image/image.dart' as img;

import 'create_post_screen.dart';

enum _LocalEffect { none, clarity, portrait, nightClean, softGlow, filmGrain }

bool _needsOrientationBake(img.Image image) =>
    image.exif.imageIfd.hasOrientation && image.exif.imageIfd.orientation != 1;

List<Uint8List> _prepareEditorTextures(String imagePath) {
  final bytes = File(imagePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Fotoğraf çözülemedi.');
  final longEdge = math.max(decoded.width, decoded.height);
  final resized = longEdge > 1440
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1440 : null,
          height: decoded.height > decoded.width ? 1440 : null,
          interpolation: img.Interpolation.cubic,
        )
      : decoded;
  // Rotate after downscaling so EXIF-oriented phone photos never create a
  // second sensor-sized bitmap just for the editor preview.
  final preview =
      _needsOrientationBake(resized) ? img.bakeOrientation(resized) : resized;
  final thumb = img.copyResize(
    preview,
    width: preview.width >= preview.height ? 260 : null,
    height: preview.height > preview.width ? 260 : null,
    interpolation: img.Interpolation.cubic,
  );
  return [
    Uint8List.fromList(img.encodeJpg(preview, quality: 96)),
    Uint8List.fromList(img.encodeJpg(thumb, quality: 90)),
  ];
}

Uint8List _renderLocalEffect(Map<String, Object> job) {
  final bytes = job['bytes']! as Uint8List;
  final effect = _LocalEffect.values[job['effect']! as int];
  final maxDimension = job['maxDimension']! as int;
  final quality = job['quality']! as int;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Efekt için fotoğraf çözülemedi.');
  var output = decoded;
  final longEdge = math.max(decoded.width, decoded.height);
  if (maxDimension > 0 && longEdge > maxDimension) {
    output = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? maxDimension : null,
      height: decoded.height > decoded.width ? maxDimension : null,
      interpolation: img.Interpolation.cubic,
    );
  }
  // Bake orientation only after an optional resize. This is the main memory
  // guard for 48/64/108 MP camera sensors.
  if (_needsOrientationBake(output)) {
    output = img.bakeOrientation(output);
  }

  const sharpen = <num>[0, -1, 0, -1, 5, -1, 0, -1, 0];
  switch (effect) {
    case _LocalEffect.none:
      break;
    case _LocalEffect.clarity:
      output = img.convolution(output, filter: sharpen, amount: .38);
    case _LocalEffect.portrait:
      output = img.smooth(output, weight: 18);
      output = img.convolution(output, filter: sharpen, amount: .08);
    case _LocalEffect.nightClean:
      output = img.gaussianBlur(output, radius: 1);
      output = img.convolution(output, filter: sharpen, amount: .24);
      output = img.adjustColor(output, gamma: .94, saturation: 1.04);
    case _LocalEffect.softGlow:
      final soft = img.gaussianBlur(img.Image.from(output), radius: 5);
      for (final pixel in output) {
        final glow = soft.getPixel(pixel.x, pixel.y);
        final maxValue = pixel.maxChannelValue;
        final screenR = maxValue -
            ((maxValue - pixel.r) * (maxValue - glow.r) / maxValue);
        final screenG = maxValue -
            ((maxValue - pixel.g) * (maxValue - glow.g) / maxValue);
        final screenB = maxValue -
            ((maxValue - pixel.b) * (maxValue - glow.b) / maxValue);
        pixel
          ..r = pixel.r * .84 + screenR * .16
          ..g = pixel.g * .84 + screenG * .16
          ..b = pixel.b * .84 + screenB * .16;
      }
    case _LocalEffect.filmGrain:
      output = img.noise(
        output,
        4.2,
        type: img.NoiseType.gaussian,
        random: math.Random(42),
      );
      output = img.vignette(output, start: .52, end: .95, amount: .28);
  }

  if (job['applyTone'] == true) {
    final exposure = (job['exposure']! as num).toDouble();
    final contrast = (job['contrast']! as num).toDouble();
    final saturation = (job['saturation']! as num).toDouble();
    final vibrance = (job['vibrance']! as num).toDouble();
    final temperature = (job['temperature']! as num).toDouble();
    final tint = (job['tint']! as num).toDouble();
    final combinedSaturation =
        (saturation + vibrance * .22).clamp(0.0, 2.0).toDouble();

    output = img.adjustColor(
      output,
      brightness: math.pow(2, exposure),
      contrast: contrast,
      saturation: combinedSaturation,
    );

    // A restrained white-balance pass keeps the exported JPEG close to the
    // GPU preview without allocating another full-resolution image.
    final temperatureShift = ((temperature - 5000) / 3200).clamp(-1.0, 1.0);
    final tintShift = (tint / 100).clamp(-1.0, 1.0);
    if (temperatureShift.abs() > .001 || tintShift.abs() > .001) {
      for (final pixel in output) {
        final maxValue = pixel.maxChannelValue;
        pixel
          ..r = (pixel.r * (1 + temperatureShift * .08 - tintShift * .02))
              .clamp(0, maxValue)
          ..g = (pixel.g * (1 + tintShift * .05)).clamp(0, maxValue)
          ..b = (pixel.b * (1 - temperatureShift * .08 - tintShift * .02))
              .clamp(0, maxValue);
      }
    }

    if (job['monochrome'] == true) {
      output = img.grayscale(output);
    }
    final vignetteEnd = (job['vignetteEnd']! as num).toDouble();
    if (vignetteEnd < 1.0) {
      output = img.vignette(
        output,
        start: (job['vignetteStart']! as num).toDouble(),
        end: vignetteEnd,
        amount: .30,
      );
    }
  }

  return Uint8List.fromList(img.encodeJpg(output, quality: quality));
}

class ProFilterEditorScreen extends StatefulWidget {
  final String imagePath;
  final String? captureMode;

  const ProFilterEditorScreen({
    super.key,
    required this.imagePath,
    this.captureMode,
  });

  @override
  State<ProFilterEditorScreen> createState() => _ProFilterEditorScreenState();
}

class _PhotoLook {
  final String name;
  final String effectLabel;
  final _LocalEffect effect;
  final double exposure;
  final double contrast;
  final double saturation;
  final double vibrance;
  final double temperature;
  final double tint;
  final double shadows;
  final double highlights;
  final double vignetteStart;
  final double vignetteEnd;
  final bool monochrome;

  const _PhotoLook({
    required this.name,
    this.effectLabel = 'Ton',
    this.effect = _LocalEffect.none,
    this.exposure = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.vibrance = 0,
    this.temperature = 5000,
    this.tint = 0,
    this.shadows = 0,
    this.highlights = 1,
    this.vignetteStart = .48,
    this.vignetteEnd = 1.02,
    this.monochrome = false,
  });
}

const _looks = <_PhotoLook>[
  _PhotoLook(name: 'Doğal', effectLabel: 'Orijinal'),
  _PhotoLook(
    name: 'HDR Detay',
    effectLabel: 'Netlik + Detay',
    effect: _LocalEffect.clarity,
    exposure: .06,
    contrast: 1.08,
    saturation: .98,
    vibrance: .08,
    shadows: .16,
    highlights: .90,
  ),
  _PhotoLook(
    name: 'Portre Pro',
    effectLabel: 'Cilt Yumuşatma',
    effect: _LocalEffect.portrait,
    exposure: .12,
    contrast: 1.02,
    saturation: .94,
    vibrance: .06,
    temperature: 5850,
    tint: 5,
    shadows: .14,
    highlights: .96,
    vignetteStart: .58,
    vignetteEnd: .98,
  ),
  _PhotoLook(
    name: 'Gece Temiz',
    effectLabel: 'Kumlanma Azaltma',
    effect: _LocalEffect.nightClean,
    exposure: .10,
    contrast: 1.12,
    saturation: 1.02,
    vibrance: .14,
    temperature: 4550,
    tint: -3,
    shadows: .20,
    highlights: .84,
  ),
  _PhotoLook(
    name: 'Soft Glow',
    effectLabel: 'Işık Parlaması',
    effect: _LocalEffect.softGlow,
    exposure: .05,
    contrast: .98,
    saturation: .96,
    temperature: 6100,
    tint: 4,
    shadows: .12,
    highlights: .92,
  ),
  _PhotoLook(
    name: 'Cine Teal',
    effectLabel: 'Sinema Detayı',
    effect: _LocalEffect.clarity,
    exposure: -.10,
    contrast: 1.24,
    saturation: .80,
    vibrance: .18,
    temperature: 4350,
    tint: -7,
    shadows: .15,
    highlights: .84,
    vignetteStart: .38,
    vignetteEnd: .84,
  ),
  _PhotoLook(
    name: 'Analog Film',
    effectLabel: 'Gerçek Gren',
    effect: _LocalEffect.filmGrain,
    exposure: .02,
    contrast: .90,
    saturation: .82,
    temperature: 5650,
    tint: 3,
    shadows: .22,
    highlights: .90,
  ),
  _PhotoLook(
    name: 'Mono Grain',
    effectLabel: 'S/B + Gren',
    effect: _LocalEffect.filmGrain,
    exposure: -.03,
    contrast: 1.25,
    saturation: 0,
    shadows: .16,
    highlights: .88,
    monochrome: true,
  ),
];

class _ProFilterEditorScreenState extends State<ProFilterEditorScreen> {
  TextureSource? _texture;
  TextureSource? _basePreviewTexture;
  TextureSource? _effectTexture;
  TextureSource? _thumbTexture;
  GroupShaderConfiguration? _configuration;
  Uint8List? _sourceBytes;
  Uint8List? _previewBytes;
  bool _loading = true;
  bool _exporting = false;
  bool _processingEffect = false;
  String? _error;
  String _exportStage = 'İşleniyor';
  int _selectedLook = 0;
  int _effectRevision = 0;
  Timer? _effectDebounce;
  bool _effectRenderRunning = false;
  _LocalEffect? _pendingEffect;
  int? _pendingEffectRevision;

  double _exposure = 0;
  double _contrast = 0;
  double _saturation = 0;
  double _temperature = 0;
  double _vibrance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = File(widget.imagePath);
      final prepared = await compute(_prepareEditorTextures, widget.imagePath);
      final preview = await TextureSource.fromMemory(prepared[0]);
      final thumb = await TextureSource.fromMemory(prepared[1]);
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        // Only the lightweight preview enters GPU memory. The original JPEG
        // stays compressed until the user explicitly exports an edit.
        _texture = preview;
        _basePreviewTexture = preview;
        _thumbTexture = thumb;
        _sourceBytes = bytes;
        _previewBytes = prepared[0];
        _configuration = _buildConfiguration(_looks[_selectedLook]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  GroupShaderConfiguration _buildConfiguration(_PhotoLook look) {
    final group = GroupShaderConfiguration();

    final exposure = ExposureShaderConfiguration()
      ..exposure = (look.exposure + _exposure).clamp(-2.5, 2.5).toDouble();
    final contrast = ContrastShaderConfiguration()
      ..contrast = (look.contrast + _contrast).clamp(.45, 2.2).toDouble();
    final saturation = SaturationShaderConfiguration()
      ..saturation = (look.saturation + _saturation).clamp(0.0, 2.0).toDouble();
    final vibrance = VibranceShaderConfiguration()
      ..vibrance = (look.vibrance + _vibrance).clamp(-1.0, 1.0).toDouble();
    final whiteBalance = WhiteBalanceShaderConfiguration()
      ..temperature = (look.temperature + _temperature).clamp(2800, 8200).toDouble()
      ..tint = look.tint;
    final dynamicRange = HighlightShadowShaderConfiguration()
      ..shadows = look.shadows.clamp(0.0, 1.0).toDouble()
      ..highlights = look.highlights.clamp(0.0, 1.0).toDouble();

    group
      ..add(exposure)
      ..add(dynamicRange)
      ..add(contrast)
      ..add(saturation)
      ..add(vibrance)
      ..add(whiteBalance);

    if (look.monochrome) {
      group.add(GrayscaleShaderConfiguration());
    }

    if (look.vignetteEnd < 1.0) {
      group.add(
        VignetteShaderConfiguration()
          ..center = const math.Point<double>(.5, .5)
          ..color = Colors.black
          ..start = look.vignetteStart
          ..end = look.vignetteEnd,
      );
    }

    return group;
  }

  void _rebuildConfiguration() {
    final old = _configuration;
    setState(() {
      _configuration = _buildConfiguration(_looks[_selectedLook]);
    });
    old?.dispose();
  }

  void _selectLook(int index) {
    _effectDebounce?.cancel();
    _pendingEffect = null;
    _pendingEffectRevision = null;
    _selectedLook = index;
    _exposure = 0;
    _contrast = 0;
    _saturation = 0;
    _temperature = 0;
    _vibrance = 0;
    final revision = ++_effectRevision;
    final effect = _looks[index].effect;
    setState(() {
      _effectTexture = null;
      _processingEffect = effect != _LocalEffect.none;
    });
    _rebuildConfiguration();
    if (effect != _LocalEffect.none) {
      _effectDebounce = Timer(const Duration(milliseconds: 180), () {
        if (!mounted || revision != _effectRevision) return;
        _pendingEffect = effect;
        _pendingEffectRevision = revision;
        unawaited(_drainEffectQueue());
      });
    }
  }

  Future<void> _drainEffectQueue() async {
    if (_effectRenderRunning) return;
    _effectRenderRunning = true;
    try {
      while (mounted && _pendingEffect != null) {
        final effect = _pendingEffect!;
        final revision = _pendingEffectRevision!;
        _pendingEffect = null;
        _pendingEffectRevision = null;
        await _loadLookEffect(effect, revision);
      }
    } finally {
      _effectRenderRunning = false;
    }
  }

  Future<void> _loadLookEffect(_LocalEffect effect, int revision) async {
    // Structural filter previews work from the already-downscaled JPEG. They
    // must never decode the sensor-sized original on every preset tap.
    final bytes = _previewBytes;
    if (bytes == null) return;
    try {
      final rendered = await compute(
        _renderLocalEffect,
        <String, Object>{
          'bytes': bytes,
          'effect': effect.index,
          'maxDimension': 0,
          'quality': 96,
        },
      );
      final texture = await TextureSource.fromMemory(rendered);
      if (!mounted || revision != _effectRevision) return;
      setState(() {
        _effectTexture = texture;
        _processingEffect = false;
      });
    } catch (e) {
      debugPrint('studio local effect: $e');
      if (mounted && revision == _effectRevision) {
        setState(() => _processingEffect = false);
      }
    }
  }

  Future<void> _exportAndContinue() async {
    if (_exporting ||
        _processingEffect ||
        _texture == null ||
        _configuration == null) {
      return;
    }
    final untouchedOriginal = _selectedLook == 0 &&
        _exposure == 0 &&
        _contrast == 0 &&
        _saturation == 0 &&
        _temperature == 0 &&
        _vibrance == 0;
    if (untouchedOriginal) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePostScreen(initialImagePath: widget.imagePath),
        ),
      );
      return;
    }

    setState(() {
      _exporting = true;
      _exportStage = 'Tam kalite işleniyor';
    });
    try {
      final sourceBytes = _sourceBytes;
      if (sourceBytes == null) throw Exception('Orijinal fotoğraf bulunamadı.');
      final look = _looks[_selectedLook];
      final heavyEffect = look.effect == _LocalEffect.portrait ||
          look.effect == _LocalEffect.nightClean ||
          look.effect == _LocalEffect.softGlow;
      final outputBytes = await compute(
        _renderLocalEffect,
        <String, Object>{
          'bytes': sourceBytes,
          'effect': look.effect.index,
          // 12 MP-class output for lightweight effects; memory-heavy blur
          // effects are bounded to roughly 8 MP to prevent Android OOM kills.
          'maxDimension': heavyEffect ? 3200 : 4096,
          'quality': 100,
          'applyTone': true,
          'exposure': (look.exposure + _exposure).clamp(-2.5, 2.5),
          'contrast': (look.contrast + _contrast).clamp(.45, 2.2),
          'saturation': (look.saturation + _saturation).clamp(0.0, 2.0),
          'vibrance': (look.vibrance + _vibrance).clamp(-1.0, 1.0),
          'temperature':
              (look.temperature + _temperature).clamp(2800, 8200),
          'tint': look.tint,
          'monochrome': look.monochrome,
          'vignetteStart': look.vignetteStart,
          'vignetteEnd': look.vignetteEnd,
        },
      );
      final output = File(
        '${Directory.systemTemp.path}/tbt_pro_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await output.writeAsBytes(outputBytes, flush: true);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePostScreen(initialImagePath: output.path),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf işlenemedi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportStage = 'İşleniyor';
        });
      }
    }
  }

  @override
  void dispose() {
    _effectDebounce?.cancel();
    _configuration?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? _loadingView()
            : _error != null
                ? _errorView()
                : Column(
                    children: [
                      _topBar(),
                      Expanded(child: _mainPreview()),
                      _lookStrip(),
                      _adjustments(),
                      _bottomBar(),
                    ],
                  ),
      ),
    );
  }

  Widget _loadingView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(widget.imagePath),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          cacheWidth: 1080,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const ColoredBox(color: Color(0x42000000)),
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xD916171B),
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Stüdyo hazırlanıyor',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Fotoğraf editörü açılamadı.\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Stüdyo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _selectLook(0),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
  }

  Widget _mainPreview() {
    final texture = _effectTexture ?? _basePreviewTexture ?? _texture!;
    final configuration = _configuration!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF090909),
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 8,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.hardEdge,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: texture.width.toDouble(),
                  height: texture.height.toDouble(),
                  child: PipelineImageShaderPreview(
                    key: ValueKey(
                      'main-$_selectedLook-$_exposure-$_contrast-$_saturation-$_temperature-$_vibrance-${_effectTexture != null}',
                    ),
                    texture: texture,
                    configuration: configuration,
                  ),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xA8000000),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 14),
                      SizedBox(width: 5),
                      Text(
                        '1×–8×',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_processingEffect)
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xB8000000),
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Efekt hazırlanıyor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lookStrip() {
    final texture = _thumbTexture!;
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        itemCount: _looks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = index == _selectedLook;
          final look = _looks[index];
          final config = _buildThumbnailConfiguration(look);
          return GestureDetector(
            onTap: () => _selectLook(index),
            child: SizedBox(
              width: 78,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFFC400)
                              : Colors.white24,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: texture.width.toDouble(),
                          height: texture.height.toDouble(),
                          child: PipelineImageShaderPreview(
                            texture: texture,
                            configuration: config,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    look.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  Text(
                    look.effectLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF54E6D8)
                          : Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  GroupShaderConfiguration _buildThumbnailConfiguration(_PhotoLook look) {
    final savedExposure = _exposure;
    final savedContrast = _contrast;
    final savedSaturation = _saturation;
    final savedTemperature = _temperature;
    final savedVibrance = _vibrance;
    _exposure = 0;
    _contrast = 0;
    _saturation = 0;
    _temperature = 0;
    _vibrance = 0;
    final result = _buildConfiguration(look);
    _exposure = savedExposure;
    _contrast = savedContrast;
    _saturation = savedSaturation;
    _temperature = savedTemperature;
    _vibrance = savedVibrance;
    return result;
  }

  Widget _adjustments() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0B0D),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _adjustmentRow(
            label: 'Pozlama',
            value: _exposure,
            min: -1.5,
            max: 1.5,
            onChanged: (v) => setState(() => _exposure = v),
            onChangeEnd: (_) => _rebuildConfiguration(),
          ),
          _adjustmentRow(
            label: 'Kontrast',
            value: _contrast,
            min: -.45,
            max: .55,
            onChanged: (v) => setState(() => _contrast = v),
            onChangeEnd: (_) => _rebuildConfiguration(),
          ),
          _adjustmentRow(
            label: 'Canlılık',
            value: _vibrance,
            min: -.5,
            max: .65,
            onChanged: (v) => setState(() => _vibrance = v),
            onChangeEnd: (_) => _rebuildConfiguration(),
          ),
          _adjustmentRow(
            label: 'Sıcaklık',
            value: _temperature,
            min: -1800,
            max: 1800,
            onChanged: (v) => setState(() => _temperature = v),
            onChangeEnd: (_) => _rebuildConfiguration(),
            valueText: '${_temperature >= 0 ? '+' : ''}${_temperature.round()}K',
          ),
        ],
      ),
    );
  }

  Widget _adjustmentRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    String? valueText,
  }) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFFFFC400),
                trackHeight: 2,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              valueText ?? value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _exporting ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tekrar Çek'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed:
                  _exporting || _processingEffect ? null : _exportAndContinue,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _exporting ? _exportStage : 'Devam Et',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
