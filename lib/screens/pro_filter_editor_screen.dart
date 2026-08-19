import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_filters/flutter_image_filters.dart';
import 'package:image/image.dart' as img;

import 'create_post_screen.dart';

class ProFilterEditorScreen extends StatefulWidget {
  final String imagePath;

  const ProFilterEditorScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<ProFilterEditorScreen> createState() => _ProFilterEditorScreenState();
}

class _PhotoLook {
  final String name;
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
  _PhotoLook(name: 'Natural'),
  _PhotoLook(
    name: 'Clean Pro',
    exposure: .10,
    contrast: 1.10,
    saturation: .96,
    vibrance: .10,
    shadows: .10,
    highlights: .94,
  ),
  _PhotoLook(
    name: 'Warm Street',
    exposure: -.05,
    contrast: 1.25,
    saturation: .92,
    vibrance: .18,
    temperature: 6100,
    tint: 4,
    shadows: .08,
    highlights: .88,
    vignetteStart: .42,
    vignetteEnd: .86,
  ),
  _PhotoLook(
    name: 'Golden Hour',
    exposure: .12,
    contrast: 1.16,
    saturation: 1.08,
    vibrance: .22,
    temperature: 6900,
    tint: 5,
    shadows: .12,
    highlights: .90,
    vignetteStart: .48,
    vignetteEnd: .92,
  ),
  _PhotoLook(
    name: 'Cine Teal',
    exposure: -.14,
    contrast: 1.32,
    saturation: .78,
    vibrance: .20,
    temperature: 4300,
    tint: -8,
    shadows: .15,
    highlights: .82,
    vignetteStart: .38,
    vignetteEnd: .82,
  ),
  _PhotoLook(
    name: 'Night Neon',
    exposure: .08,
    contrast: 1.36,
    saturation: 1.14,
    vibrance: .30,
    temperature: 3900,
    tint: -6,
    shadows: .18,
    highlights: .80,
    vignetteStart: .38,
    vignetteEnd: .80,
  ),
  _PhotoLook(
    name: 'Forest Deep',
    exposure: -.10,
    contrast: 1.22,
    saturation: .98,
    vibrance: .24,
    temperature: 4750,
    tint: -4,
    shadows: .14,
    highlights: .87,
    vignetteStart: .42,
    vignetteEnd: .86,
  ),
  _PhotoLook(
    name: 'Matte Film',
    exposure: .04,
    contrast: .86,
    saturation: .80,
    vibrance: -.04,
    temperature: 5750,
    tint: 3,
    shadows: .26,
    highlights: .91,
    vignetteStart: .50,
    vignetteEnd: .91,
  ),
  _PhotoLook(
    name: 'Portrait Soft',
    exposure: .16,
    contrast: 1.03,
    saturation: .91,
    vibrance: .08,
    temperature: 5900,
    tint: 6,
    shadows: .15,
    highlights: .95,
    vignetteStart: .56,
    vignetteEnd: .98,
  ),
  _PhotoLook(
    name: 'Mono 400',
    exposure: -.03,
    contrast: 1.34,
    saturation: 0,
    shadows: .16,
    highlights: .86,
    vignetteStart: .40,
    vignetteEnd: .82,
    monochrome: true,
  ),
];

class _ProFilterEditorScreenState extends State<ProFilterEditorScreen> {
  TextureSource? _texture;
  TextureSource? _thumbTexture;
  GroupShaderConfiguration? _configuration;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  int _selectedLook = 0;

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
      final texture = await TextureSource.fromFile(file);

      TextureSource thumbTexture = texture;
      try {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 220 : null,
            height: decoded.height >= decoded.width ? 220 : null,
          );
          final thumbBytes = img.encodeJpg(resized, quality: 82);
          thumbTexture = await TextureSource.fromMemory(thumbBytes);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _texture = texture;
        _thumbTexture = thumbTexture;
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
    _selectedLook = index;
    _exposure = 0;
    _contrast = 0;
    _saturation = 0;
    _temperature = 0;
    _vibrance = 0;
    _rebuildConfiguration();
  }

  Future<void> _exportAndContinue() async {
    if (_exporting || _texture == null || _configuration == null) return;
    setState(() => _exporting = true);
    try {
      final rendered = await _configuration!.export(_texture!, _texture!.size);
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('GPU çıktısı oluşturulamadı.');
      final output = File(
        '${Directory.systemTemp.path}/tbt_gpu_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await output.writeAsBytes(data.buffer.asUint8List(), flush: true);
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
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void dispose() {
    _configuration?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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
            onPressed: () {
              _selectedLook = 0;
              _exposure = 0;
              _contrast = 0;
              _saturation = 0;
              _temperature = 0;
              _vibrance = 0;
              _rebuildConfiguration();
            },
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
  }

  Widget _mainPreview() {
    final texture = _texture!;
    final configuration = _configuration!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF090909),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: texture.width.toDouble(),
            height: texture.height.toDouble(),
            child: PipelineImageShaderPreview(
              key: ValueKey(
                'main-$_selectedLook-$_exposure-$_contrast-$_saturation-$_temperature-$_vibrance',
              ),
              texture: texture,
              configuration: configuration,
            ),
          ),
        ),
      ),
    );
  }

  Widget _lookStrip() {
    final texture = _thumbTexture!;
    return SizedBox(
      height: 106,
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
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
              onPressed: _exporting ? null : _exportAndContinue,
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
                _exporting ? 'İşleniyor' : 'Devam Et',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
