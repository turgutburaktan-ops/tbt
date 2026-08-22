import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../services/story_service.dart';

class StoryPhotoEditorScreen extends StatefulWidget {
  final File photo;

  const StoryPhotoEditorScreen({
    super.key,
    required this.photo,
  });

  @override
  State<StoryPhotoEditorScreen> createState() => _StoryPhotoEditorScreenState();
}

class _StoryPhotoEditorScreenState extends State<StoryPhotoEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();

  final List<_StoryOverlay> _overlays = <_StoryOverlay>[];
  final List<_DrawStroke> _strokes = <_DrawStroke>[];

  int? _selectedIndex;
  bool _sharing = false;
  bool _editingText = false;
  bool _emojiInput = false;
  bool _drawing = false;
  bool _movingOverlay = false;
  bool _overTrash = false;
  bool _editingBackground = false;
  Size? _sourceSize;
  _DrawStroke? _activeStroke;

  double _backgroundScale = 1;
  double _backgroundRotation = 0;
  Offset _backgroundOffset = Offset.zero;
  double _backgroundStartScale = 1;
  double _backgroundStartRotation = 0;

  _FontOption _font = _fonts.first;
  Color _textColor = Colors.white;
  Color _drawColor = Colors.white;

  static const _fonts = <_FontOption>[
    _FontOption('Modern', 'sans-serif'),
    _FontOption('Klasik', 'serif'),
    _FontOption('Daktilo', 'monospace'),
    _FontOption('Yuvarlak', 'sans-serif-medium'),
    _FontOption('İnce', 'sans-serif-light'),
  ];

  static const _colors = <Color>[
    Colors.white,
    Colors.black,
    Color(0xFFFFE25C),
    Color(0xFFFF5C8A),
    Color(0xFF74E7FF),
    Color(0xFFC79AFF),
    Color(0xFF8EFFB5),
  ];

  @override
  void initState() {
    super.initState();
    _readSourceSize();
  }

  Future<void> _readSourceSize() async {
    try {
      final bytes = await widget.photo.readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _sourceSize = Size(image.width.toDouble(), image.height.toDouble()));
      image.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _textFocus.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _openText({bool emoji = false}) {
    if (_sharing) return;
    setState(() {
      _editingText = true;
      _emojiInput = emoji;
      _drawing = false;
      _editingBackground = false;
      _selectedIndex = null;
      _textController.clear();
      _font = _fonts.first;
      _textColor = Colors.white;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  void _cancelText() {
    _textFocus.unfocus();
    setState(() {
      _editingText = false;
      _emojiInput = false;
      _textController.clear();
    });
  }

  void _commitText() {
    final value = _textController.text.trim();
    if (value.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _overlays.add(
        _StoryOverlay.text(
          text: value,
          isEmoji: _emojiInput,
          fontFamily: _font.family,
          color: _textColor,
          position: Offset(size.width * .5, size.height * .43),
        ),
      );
      _selectedIndex = _overlays.length - 1;
      _editingText = false;
      _emojiInput = false;
      _textController.clear();
    });
    _textFocus.unfocus();
  }

  Future<void> _addPhotos() async {
    if (_sharing) return;
    _textFocus.unfocus();
    try {
      final picked = await _picker.pickMultiImage();
      if (!mounted || picked.isEmpty) return;
      final size = MediaQuery.sizeOf(context);
      final remaining = math.max(0, 4 - _overlays.where((item) => item.photo != null).length);
      final files = picked.take(remaining).toList();
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir Story karesine en fazla 4 ek fotoğraf koyabilirsin.')),
        );
        return;
      }
      setState(() {
        _drawing = false;
        _editingBackground = false;
        for (var i = 0; i < files.length; i++) {
          final dx = size.width * (.5 + ((i % 2) - .5) * .18);
          final dy = size.height * (.42 + (i ~/ 2) * .12);
          _overlays.add(
            _StoryOverlay.photo(
              photo: File(files[i].path),
              position: Offset(dx, dy),
            ),
          );
        }
        _selectedIndex = _overlays.length - 1;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf seçilemedi: $error')),
      );
    }
  }

  void _toggleDraw() {
    if (_sharing) return;
    _textFocus.unfocus();
    setState(() {
      _drawing = !_drawing;
      _editingText = false;
      _editingBackground = false;
      _selectedIndex = null;
    });
  }

  void _toggleBackgroundEdit() {
    if (_sharing) return;
    _textFocus.unfocus();
    setState(() {
      _editingBackground = !_editingBackground;
      _drawing = false;
      _editingText = false;
      _selectedIndex = null;
    });
  }

  void _undoDraw() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _removeSelected() {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _overlays.length) return;
    setState(() {
      _overlays.removeAt(index);
      _selectedIndex = null;
      _overTrash = false;
      _movingOverlay = false;
    });
  }

  double _renderPixelRatio(RenderRepaintBoundary boundary) {
    final source = _sourceSize;
    final canvas = boundary.size;
    final deviceRatio = MediaQuery.devicePixelRatioOf(context);
    if (source == null || source.width <= 0 || source.height <= 0 ||
        canvas.width <= 0 || canvas.height <= 0) {
      return math.max(3.0, deviceRatio);
    }
    final coverScale = math.max(canvas.width / source.width, canvas.height / source.height);
    final sourcePixelRatio = 1 / coverScale;
    return math.max(deviceRatio, sourcePixelRatio);
  }

  Future<File> _renderStory() async {
    if (!mounted) throw Exception('Story ekranı kapandı.');
    setState(() {
      _selectedIndex = null;
      _editingText = false;
      _drawing = false;
      _editingBackground = false;
      _movingOverlay = false;
      _overTrash = false;
    });
    _textFocus.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) throw Exception('Story ekranı kapandı.');

    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('Story görüntüsü hazırlanamadı.');
    }

    final ratio = _renderPixelRatio(renderObject);
    final image = await renderObject.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw Exception('Story görüntüsü oluşturulamadı.');

    final file = File('${Directory.systemTemp.path}/tbt_story_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    File? rendered;
    try {
      rendered = await _renderStory();
      await StoryService.instance.createStory(rendered);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      try {
        if (rendered != null && await rendered.exists()) await rendered.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sharing,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _drawing ? null : () => setState(() => _selectedIndex = null),
                      onScaleStart: !_editingBackground
                          ? null
                          : (_) {
                              _backgroundStartScale = _backgroundScale;
                              _backgroundStartRotation = _backgroundRotation;
                            },
                      onScaleUpdate: !_editingBackground
                          ? null
                          : (details) {
                              setState(() {
                                _backgroundOffset += details.focalPointDelta;
                                _backgroundScale = (_backgroundStartScale * details.scale).clamp(1.0, 6.0);
                                _backgroundRotation = _backgroundStartRotation + details.rotation;
                              });
                            },
                      child: Transform.translate(
                        offset: _backgroundOffset,
                        child: Transform.rotate(
                          angle: _backgroundRotation,
                          child: Transform.scale(
                            scale: _backgroundScale,
                            child: Image.file(
                              widget.photo,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _DrawingPainter(strokes: _strokes, activeStroke: _activeStroke),
                    ),
                    ...List.generate(_overlays.length, _buildOverlay),
                  ],
                ),
              ),
            ),
            if (_drawing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (details) {
                    setState(() {
                      _activeStroke = _DrawStroke(
                        color: _drawColor,
                        width: 5.5,
                        points: <Offset>[details.localPosition],
                      );
                    });
                  },
                  onPanUpdate: (details) => setState(() => _activeStroke?.points.add(details.localPosition)),
                  onPanEnd: (_) {
                    final stroke = _activeStroke;
                    setState(() {
                      if (stroke != null && stroke.points.length > 1) _strokes.add(stroke);
                      _activeStroke = null;
                    });
                  },
                ),
              ),
            if (!_editingText) _buildChrome(),
            if (_editingText) _buildTextComposer(),
            if (_movingOverlay) _buildTrashTarget(),
          ],
        ),
      ),
    );
  }

  Widget _buildChrome() {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _CircleButton(icon: Icons.close_rounded, onTap: _sharing ? null : () => Navigator.of(context).pop(false)),
                  const Spacer(),
                  _CircleButton(icon: Icons.text_fields_rounded, onTap: _sharing ? null : () => _openText()),
                  const SizedBox(width: 7),
                  _CircleButton(icon: Icons.emoji_emotions_outlined, onTap: _sharing ? null : () => _openText(emoji: true)),
                  const SizedBox(width: 7),
                  _CircleButton(icon: Icons.add_photo_alternate_outlined, onTap: _sharing ? null : _addPhotos),
                  const SizedBox(width: 7),
                  _CircleButton(icon: _editingBackground ? Icons.check_rounded : Icons.zoom_out_map_rounded, onTap: _sharing ? null : _toggleBackgroundEdit),
                  const SizedBox(width: 7),
                  _CircleButton(icon: _drawing ? Icons.check_rounded : Icons.draw_outlined, onTap: _sharing ? null : _toggleDraw),
                ],
              ),
              if (_editingBackground)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(18)),
                  child: const Text(
                    'Ana fotoğraf: sürükle • iki parmakla büyüt/küçült ve döndür',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              if (_drawing) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in _colors)
                      GestureDetector(
                        onTap: () => setState(() => _drawColor = color),
                        child: Container(
                          width: 29,
                          height: 29,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: _drawColor == color ? Colors.white : Colors.white38, width: _drawColor == color ? 3 : 1),
                          ),
                        ),
                      ),
                    const SizedBox(width: 5),
                    _CircleButton(icon: Icons.undo_rounded, compact: true, onTap: _strokes.isEmpty ? null : _undoDraw),
                  ],
                ),
              ],
              const Spacer(),
              if (!_drawing && !_editingBackground)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sharing ? null : _share,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Colors.black54,
                          side: const BorderSide(color: Colors.white30),
                        ),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: Text(_sharing ? 'Paylaşılıyor…' : 'Story’n'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _sharing ? null : _share,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(58, 52),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                      ),
                      child: _sharing
                          ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: Colors.black.withValues(alpha: .18)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Row(
                    children: [
                      TextButton(onPressed: _cancelText, child: const Text('Vazgeç', style: TextStyle(color: Colors.white))),
                      const Spacer(),
                      TextButton(onPressed: _commitText, child: const Text('Bitti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocus,
                    autofocus: true,
                    maxLength: 180,
                    minLines: 1,
                    maxLines: 5,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      fontFamily: _emojiInput ? null : _font.family,
                      color: _textColor,
                      fontSize: _emojiInput ? 54 : 34,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 1))],
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      hintText: _emojiInput ? 'Emoji klavyeni aç ve emojini seç' : 'Yazmaya başla…',
                      hintStyle: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                const Spacer(),
                if (!_emojiInput)
                  Padding(
                    padding: EdgeInsets.only(bottom: keyboard > 0 ? 8 : 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            scrollDirection: Axis.horizontal,
                            itemCount: _fonts.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, index) {
                              final item = _fonts[index];
                              final selected = item.family == _font.family;
                              return GestureDetector(
                                onTap: () => setState(() => _font = item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: selected ? Colors.white : Colors.black54, borderRadius: BorderRadius.circular(20)),
                                  child: Text(item.label, style: TextStyle(fontFamily: item.family, color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.w800)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final color in _colors)
                              GestureDetector(
                                onTap: () => setState(() => _textColor = color),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _textColor == color ? Colors.white : Colors.white38, width: _textColor == color ? 3 : 1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashTarget() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _overTrash ? 64 : 54,
            height: _overTrash ? 64 : 54,
            decoration: BoxDecoration(
              color: _overTrash ? Colors.redAccent : Colors.black87,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(int index) {
    final item = _overlays[index];
    final selected = _selectedIndex == index;
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _drawing || _editingBackground ? null : () => setState(() => _selectedIndex = index),
          onScaleStart: _drawing || _editingBackground
              ? null
              : (_) {
                  item.gestureStartScale = item.scale;
                  item.gestureStartRotation = item.rotation;
                  setState(() {
                    _selectedIndex = index;
                    _movingOverlay = true;
                  });
                },
          onScaleUpdate: _drawing || _editingBackground
              ? null
              : (details) {
                  final screenHeight = MediaQuery.sizeOf(context).height;
                  setState(() {
                    item.position += details.focalPointDelta;
                    item.scale = (item.gestureStartScale * details.scale).clamp(.2, 7.0);
                    item.rotation = item.gestureStartRotation + details.rotation;
                    _overTrash = details.focalPoint.dy > screenHeight - 125;
                  });
                },
          onScaleEnd: _drawing || _editingBackground
              ? null
              : (_) {
                  if (_overTrash) {
                    _removeSelected();
                  } else {
                    setState(() {
                      _movingOverlay = false;
                      _overTrash = false;
                    });
                  }
                },
          child: Transform.rotate(
            angle: item.rotation,
            child: Transform.scale(
              scale: item.scale,
              child: item.photo != null
                  ? Container(
                      width: 180,
                      height: 230,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: selected && !_movingOverlay ? Border.all(color: Colors.white, width: 2) : null,
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.file(
                        item.photo!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: selected && !_movingOverlay
                          ? BoxDecoration(border: Border.all(color: Colors.white70), borderRadius: BorderRadius.circular(8))
                          : null,
                      child: Text(
                        item.text!,
                        textAlign: TextAlign.center,
                        style: item.isEmoji
                            ? const TextStyle(fontSize: 58)
                            : TextStyle(
                                color: item.color,
                                fontFamily: item.fontFamily,
                                fontSize: 34,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                shadows: const [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 1))],
                              ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryOverlay {
  final String? text;
  final bool isEmoji;
  final String? fontFamily;
  final Color color;
  final File? photo;
  Offset position;
  double scale;
  double rotation;
  double gestureStartScale;
  double gestureStartRotation;

  _StoryOverlay._({
    required this.text,
    required this.isEmoji,
    required this.fontFamily,
    required this.color,
    required this.photo,
    required this.position,
    this.scale = 1,
    this.rotation = 0,
    this.gestureStartScale = 1,
    this.gestureStartRotation = 0,
  });

  factory _StoryOverlay.text({
    required String text,
    required bool isEmoji,
    required String fontFamily,
    required Color color,
    required Offset position,
  }) => _StoryOverlay._(
        text: text,
        isEmoji: isEmoji,
        fontFamily: fontFamily,
        color: color,
        photo: null,
        position: position,
      );

  factory _StoryOverlay.photo({
    required File photo,
    required Offset position,
  }) => _StoryOverlay._(
        text: null,
        isEmoji: false,
        fontFamily: null,
        color: Colors.white,
        photo: photo,
        position: position,
      );
}

class _FontOption {
  final String label;
  final String family;
  const _FontOption(this.label, this.family);
}

class _DrawStroke {
  final Color color;
  final double width;
  final List<Offset> points;

  _DrawStroke({required this.color, required this.width, required this.points});
}

class _DrawingPainter extends CustomPainter {
  final List<_DrawStroke> strokes;
  final _DrawStroke? activeStroke;

  const _DrawingPainter({required this.strokes, required this.activeStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in <_DrawStroke>[...strokes, if (activeStroke != null) activeStroke!]) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  const _CircleButton({required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 44.0;
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: compact ? 19 : 22, color: onTap == null ? Colors.white30 : Colors.white),
        ),
      ),
    );
  }
}
