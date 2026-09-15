import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_theme.dart';
import '../utils/post_photo_frame.dart';

/// Normalized source rectangle. Gestures and export use the same coordinates.
Rect photoCropRect(Size image, double width, Offset center) {
  final maxWidth = math.min(1.0, postPhotoAspectRatio * image.height / image.width);
  final w = width.clamp(maxWidth / 8, maxWidth).toDouble();
  final h = w * image.width / (postPhotoAspectRatio * image.height);
  final x = center.dx.clamp(w / 2, 1 - w / 2).toDouble();
  final y = center.dy.clamp(h / 2, 1 - h / 2).toDouble();
  return Rect.fromLTWH((x - w / 2).clamp(0.0, 1.0),
      (y - h / 2).clamp(0.0, 1.0), w, h);
}

Future<Map<String, Object>> _loadPreview(Map<String, Object> args) async {
  final decoded = img.decodeImage(File(args['path'] as String).readAsBytesSync());
  if (decoded == null) throw const FormatException('Fotoğraf okunamadı.');
  var oriented = img.bakeOrientation(decoded);
  final turns = args['turns'] as int;
  if (turns % 4 != 0) oriented = img.copyRotate(oriented, angle: (turns % 4) * 90);
  final size = <int>[oriented.width, oriented.height];
  if (math.max(oriented.width, oriented.height) > 1600) {
    oriented = oriented.width >= oriented.height
        ? img.copyResize(oriented, width: 1600)
        : img.copyResize(oriented, height: 1600);
  }
  return {'bytes': Uint8List.fromList(img.encodeJpg(oriented, quality: 92)), 'size': size};
}

class PostPhotoCropScreen extends StatefulWidget {
  final File original;
  final int turns;
  final Rect? initialCrop;
  final Rect? resetCrop;
  const PostPhotoCropScreen({super.key, required this.original, this.turns = 0,
    this.initialCrop, this.resetCrop});
  @override
  State<PostPhotoCropScreen> createState() => _PostPhotoCropScreenState();
}

class _PostPhotoCropScreenState extends State<PostPhotoCropScreen> {
  Uint8List? _bytes;
  Size? _size;
  Rect? _crop;
  Rect? _reset;
  Rect? _gestureStart;
  Offset? _anchor;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await compute(_loadPreview, <String, Object>{
        'path': widget.original.path, 'turns': widget.turns,
      });
      if (!mounted) return;
      final dimensions = data['size'] as List<int>;
      final size = Size(dimensions[0].toDouble(), dimensions[1].toDouble());
      Rect normalize(Rect? r) => photoCropRect(size, r?.width ?? 1, r?.center ?? const Offset(.5, .5));
      setState(() {
        _bytes = data['bytes'] as Uint8List;
        _size = size;
        _reset = normalize(widget.resetCrop);
        _crop = normalize(widget.initialCrop ?? widget.resetCrop);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Fotoğraf açılamadı. Geri dönüp tekrar dene.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Kadrajı düzenle'), actions: [
      TextButton(onPressed: _crop == null ? null : () => Navigator.pop(context, _crop),
        child: const Text('Tamam')),
    ]),
    body: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.all(16),
        child: Text('Fotoğrafı sürükle, iki parmakla yakınlaştır.', textAlign: TextAlign.center)),
      Expanded(child: _error != null ? Center(child: Text(_error!))
        : _bytes == null ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(builder: (context, bounds) {
          final width = math.min(bounds.maxWidth, bounds.maxHeight * postPhotoAspectRatio);
          final height = width / postPhotoAspectRatio;
          final crop = _crop!;
          return Center(child: SizedBox(width: width, height: height,
            child: GestureDetector(
              onScaleStart: (details) {
                _gestureStart = _crop;
                _anchor = Offset(crop.left + details.localFocalPoint.dx / width * crop.width,
                    crop.top + details.localFocalPoint.dy / height * crop.height);
              },
              onScaleUpdate: (details) {
                final start = _gestureStart!;
                final next = photoCropRect(_size!, start.width / details.scale, start.center);
                final center = Offset(
                  _anchor!.dx + (.5 - details.localFocalPoint.dx / width) * next.width,
                  _anchor!.dy + (.5 - details.localFocalPoint.dy / height) * next.height);
                setState(() => _crop = photoCropRect(_size!, next.width, center));
              },
              child: ClipRect(child: Stack(fit: StackFit.expand, children: [
                CustomPaint(painter: _CropBackground()),
                OverflowBox(alignment: Alignment.topLeft,
                  minWidth: width / crop.width, maxWidth: width / crop.width,
                  minHeight: height / crop.height, maxHeight: height / crop.height,
                  child: Transform.translate(
                    offset: Offset(-crop.left * width / crop.width, -crop.top * height / crop.height),
                    child: Image.memory(_bytes!, fit: BoxFit.fill, gaplessPlayback: true))),
                IgnorePointer(child: CustomPaint(painter: _CropGrid())),
              ])),
            ),
          ));
        })),
      Padding(padding: const EdgeInsets.all(16), child: TextButton.icon(
        onPressed: _crop == null ? null : () => setState(() => _crop = _reset),
        icon: const Icon(Icons.restart_alt), label: const Text('Sıfırla'))),
    ])),
  );
}

class _CropBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
  @override
  bool shouldRepaint(covariant _CropBackground oldDelegate) => false;
}

class _CropGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white38..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, paint);
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _CropGrid oldDelegate) => false;
}
