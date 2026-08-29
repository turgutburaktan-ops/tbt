import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../services/story_service.dart';

class StoryPhotoEditorScreen extends StatefulWidget {
  final File photo;
  const StoryPhotoEditorScreen({super.key, required this.photo});

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
  final List<File?> _layoutSlots = <File?>[];

  int? _selectedIndex;
  int _layoutCount = 0;
  bool _sharing = false,
      _exporting = false,
      _editingText = false,
      _emojiInput = false,
      _drawing = false,
      _movingOverlay = false,
      _overTrash = false,
      _editingBackground = false;
  Size? _sourceSize;
  _DrawStroke? _activeStroke;
  double _backgroundScale = 1,
      _backgroundRotation = 0,
      _backgroundStartScale = 1,
      _backgroundStartRotation = 0;
  Offset _backgroundOffset = Offset.zero;
  _FontOption _font = _fonts.first;
  Color _textColor = Colors.white, _drawColor = Colors.white;

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

  void _finishMode() {
    _textFocus.unfocus();
    if (_editingText) {
      final value = _textController.text.trim();
      if (value.isNotEmpty) {
        _commitText();
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _editingText = false;
      _emojiInput = false;
      _drawing = false;
      _editingBackground = false;
      _selectedIndex = null;
      _activeStroke = null;
      _movingOverlay = false;
      _overTrash = false;
    });
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
    if (value.isEmpty) {
      _cancelText();
      return;
    }
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
      final remaining = math.max(0, 10 - _overlays.where((e) => e.photo != null).length);
      final files = picked.take(remaining).toList();
      if (files.isEmpty) return;
      setState(() {
        _drawing = false;
        _editingBackground = false;
        for (var i = 0; i < files.length; i++) {
          _overlays.add(
            _StoryOverlay.photo(
              photo: File(files[i].path),
              position: Offset(
                size.width * (.5 + ((i % 2) - .5) * .18),
                size.height * (.40 + (i ~/ 2) * .08),
              ),
            ),
          );
        }
        _selectedIndex = _overlays.length - 1;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $error')),
        );
      }
    }
  }

  Future<void> _openMentionPicker() async {
    if (_sharing) return;
    _finishMode();
    final selected = await showModalBottomSheet<_MentionChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => const _MentionPickerSheet(),
    );
    if (!mounted || selected == null) return;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _overlays.add(
        _StoryOverlay.mention(
          text: '@${selected.label}',
          targetUserId: selected.userId,
          position: Offset(size.width * .5, size.height * .46),
        ),
      );
      _selectedIndex = _overlays.length - 1;
    });
  }

  Future<void> _chooseLayout() async {
    if (_sharing) return;
    _finishMode();
    final choice = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 42,
                child: Divider(thickness: 4, color: Colors.white24),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Yerleşim', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
              'Her bölmeye ayrı bir fotoğraf ekleyebilirsin.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (final count in const [2, 4, 8]) ...[
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(sheetContext, count),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 112,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181B20),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _layoutCount == count ? Colors.white : Colors.white12,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(child: _LayoutPreview(count: count)),
                            const SizedBox(height: 7),
                            Text('$count’li', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (count != 8) const SizedBox(width: 10),
                ],
              ],
            ),
            if (_layoutCount > 0) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 0),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Yerleşimi kaldır'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() {
      _layoutCount = choice;
      _layoutSlots
        ..clear()
        ..addAll(List<File?>.filled(choice, null));
      _editingBackground = false;
    });
  }

  Future<void> _pickLayoutPhoto(int index) async {
    if (_sharing || index < 0 || index >= _layoutSlots.length) return;
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (!mounted || picked == null) return;
      setState(() => _layoutSlots[index] = File(picked.path));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $error')),
        );
      }
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
    if (_sharing || _layoutCount > 0) return;
    _textFocus.unfocus();
    setState(() {
      _editingBackground = !_editingBackground;
      _drawing = false;
      _editingText = false;
      _selectedIndex = null;
    });
  }

  void _startBackgroundGesture(ScaleStartDetails details) {
    _backgroundStartScale = _backgroundScale;
    _backgroundStartRotation = _backgroundRotation;
  }

  void _updateBackgroundGesture(ScaleUpdateDetails details) {
    if (!_editingBackground || _sharing) return;
    setState(() {
      _backgroundOffset += details.focalPointDelta;
      final next = _backgroundStartScale * details.scale;
      _backgroundScale = next.isFinite ? next.clamp(.05, 30.0).toDouble() : _backgroundScale;
      _backgroundRotation = _backgroundStartRotation + details.rotation;
    });
  }

  void _undoDraw() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  void _removeSelected() {
    final i = _selectedIndex;
    if (i == null || i < 0 || i >= _overlays.length) return;
    setState(() {
      _overlays.removeAt(i);
      _selectedIndex = null;
      _overTrash = false;
      _movingOverlay = false;
    });
  }

  void _duplicateSelected() {
    final i = _selectedIndex;
    if (i == null || i < 0 || i >= _overlays.length) return;
    final item = _overlays[i];
    setState(() {
      _overlays.add(item.copyWith(position: item.position + const Offset(22, 22)));
      _selectedIndex = _overlays.length - 1;
    });
  }

  void _bringSelectedForward() {
    final i = _selectedIndex;
    if (i == null || i < 0 || i >= _overlays.length - 1) return;
    setState(() {
      final item = _overlays.removeAt(i);
      _overlays.add(item);
      _selectedIndex = _overlays.length - 1;
    });
  }

  double _renderPixelRatio(RenderRepaintBoundary boundary) {
    final source = _sourceSize;
    final canvas = boundary.size;
    final deviceRatio = MediaQuery.devicePixelRatioOf(context);
    if (source == null || source.width <= 0 || source.height <= 0 || canvas.width <= 0 || canvas.height <= 0) {
      return math.max(3.0, deviceRatio).toDouble();
    }
    final contain = math.min(canvas.width / source.width, canvas.height / source.height);
    return math.max(deviceRatio, contain > 0 ? 1 / contain : 3.0).toDouble();
  }

  Future<File> _renderStory() async {
    setState(() {
      _selectedIndex = null;
      _editingText = false;
      _drawing = false;
      _editingBackground = false;
      _movingOverlay = false;
      _overTrash = false;
      _exporting = true;
    });
    _textFocus.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) throw Exception('Story ekranı kapandı.');
    final object = _canvasKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) throw Exception('Story görüntüsü hazırlanamadı.');
    try {
      final image = await object.toImage(pixelRatio: _renderPixelRatio(object));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw Exception('Story görüntüsü oluşturulamadı.');
      final file = File('${Directory.systemTemp.path}/tbt_story_${DateTime.now().microsecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file;
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    File? rendered;
    try {
      rendered = await _renderStory();
      final mentionIds = _overlays
          .map((item) => item.targetUserId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      await StoryService.instance.createStory(rendered, mentionedUserIds: mentionIds);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      try {
        if (rendered != null && await rendered.exists()) await rendered.delete();
      } catch (_) {}
    }
  }

  Widget _backgroundMedia() {
    if (_layoutCount > 0) return _buildLayoutCanvas();
    return ColoredBox(
      color: Colors.black,
      child: Transform.translate(
        offset: _backgroundOffset,
        child: Transform.rotate(
          angle: _backgroundRotation,
          child: Transform.scale(
            scale: _backgroundScale,
            child: Image.file(
              widget.photo,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutCanvas() {
    final columns = 2;
    final rows = (_layoutCount / columns).ceil();
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: List.generate(rows, (row) {
          return Expanded(
            child: Row(
              children: List.generate(columns, (col) {
                final index = row * columns + col;
                if (index >= _layoutCount) return const Expanded(child: SizedBox());
                final file = _layoutSlots[index];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Material(
                        color: const Color(0xFF111318),
                        child: InkWell(
                          onTap: _exporting ? null : () => _pickLayoutPhoto(index),
                          child: file == null
                              ? Center(
                                  child: _exporting
                                      ? const SizedBox()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_rounded, size: 34, color: Colors.white70),
                                            const SizedBox(height: 4),
                                            Text('${index + 1}. fotoğraf', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                          ],
                                        ),
                                )
                              : Image.file(
                                  file,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                  gaplessPlayback: true,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
                        onTap: _drawing || _editingBackground ? null : _finishMode,
                        child: _backgroundMedia(),
                      ),
                      CustomPaint(
                        painter: _DrawingPainter(strokes: _strokes, activeStroke: _activeStroke),
                      ),
                      ...List.generate(_overlays.length, _buildOverlay),
                    ],
                  ),
                ),
              ),
              if (_editingBackground)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _finishMode,
                    onScaleStart: _startBackgroundGesture,
                    onScaleUpdate: _updateBackgroundGesture,
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              if (_drawing)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _finishMode,
                    onPanStart: (details) => setState(
                      () => _activeStroke = _DrawStroke(color: _drawColor, width: 5.5, points: [details.localPosition]),
                    ),
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

  Widget _buildChrome() => Positioned.fill(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: _CircleButton(
                    icon: Icons.close_rounded,
                    onTap: _sharing ? null : () => Navigator.pop(context, false),
                  ),
                ),
                if (!_drawing && !_editingBackground)
                  Align(
                    alignment: Alignment.topRight,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToolButton(icon: Icons.text_fields_rounded, label: 'Yazı', onTap: () => _openText()),
                          const SizedBox(height: 8),
                          _ToolButton(icon: Icons.emoji_emotions_outlined, label: 'Emoji', onTap: () => _openText(emoji: true)),
                          const SizedBox(height: 8),
                          _ToolButton(icon: Icons.alternate_email_rounded, label: 'Bahset', onTap: _openMentionPicker),
                          const SizedBox(height: 8),
                          _ToolButton(icon: Icons.grid_view_rounded, label: 'Yerleşim', onTap: _chooseLayout),
                          const SizedBox(height: 8),
                          _ToolButton(icon: Icons.add_photo_alternate_outlined, label: 'Fotoğraf', onTap: _addPhotos),
                          const SizedBox(height: 8),
                          _ToolButton(icon: Icons.draw_outlined, label: 'Çiz', onTap: _toggleDraw),
                          const SizedBox(height: 8),
                          _ToolButton(
                            icon: Icons.crop_free_rounded,
                            label: 'Kadraj',
                            onTap: _layoutCount > 0 ? () {} : _toggleBackgroundEdit,
                            disabled: _layoutCount > 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_drawing)
                  Align(
                    alignment: Alignment.topRight,
                    child: _ModePanel(
                      title: 'Çizim',
                      done: _finishMode,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: _colors
                                .map(
                                  (color) => GestureDetector(
                                    onTap: () => setState(() => _drawColor = color),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _drawColor == color ? Colors.white : Colors.white38,
                                          width: _drawColor == color ? 3 : 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 9),
                          IconButton(onPressed: _strokes.isEmpty ? null : _undoDraw, icon: const Icon(Icons.undo_rounded)),
                        ],
                      ),
                    ),
                  ),
                if (_editingBackground)
                  Align(
                    alignment: Alignment.topRight,
                    child: _ModePanel(
                      title: 'Kadraj',
                      done: _finishMode,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Sürükle\nİki parmakla serbestçe ölçekle ve döndür',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.35),
                        ),
                      ),
                    ),
                  ),
                if (_selectedIndex != null && !_movingOverlay && !_drawing && !_editingBackground)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 72),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xD916181D),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(tooltip: 'Çoğalt', onPressed: _duplicateSelected, icon: const Icon(Icons.copy_rounded)),
                            IconButton(tooltip: 'Öne getir', onPressed: _bringSelectedForward, icon: const Icon(Icons.flip_to_front_rounded)),
                            IconButton(tooltip: 'Sil', onPressed: _removeSelected, icon: const Icon(Icons.delete_outline_rounded)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_drawing && !_editingBackground)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _sharing ? null : _share,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        icon: _sharing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.arrow_upward_rounded),
                        label: Text(
                          _sharing ? 'Paylaşılıyor…' : 'Story’ni paylaş',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _buildTextComposer() {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _commitText,
        child: Container(
          color: Colors.black45,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _cancelText,
                        child: const Text('Vazgeç', style: TextStyle(color: Colors.white)),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _commitText,
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        child: const Text('Bitti', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
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
                      shadows: _emojiInput
                          ? const []
                          : const [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 1))],
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: _emojiInput ? 'Emoji seç' : 'Bir şey yaz…',
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
                            itemBuilder: (_, i) {
                              final font = _fonts[i];
                              final selected = font.family == _font.family;
                              return GestureDetector(
                                onTap: () => setState(() => _font = font),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected ? Colors.white : Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    font.label,
                                    style: TextStyle(
                                      fontFamily: font.family,
                                      color: selected ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _colors
                              .map(
                                (color) => GestureDetector(
                                  onTap: () => setState(() => _textColor = color),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _textColor == color ? Colors.white : Colors.white38,
                                        width: _textColor == color ? 3 : 1,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrashTarget() => Positioned(
        left: 0,
        right: 0,
        bottom: 20,
        child: SafeArea(
          top: false,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _overTrash ? 68 : 56,
              height: _overTrash ? 68 : 56,
              decoration: BoxDecoration(
                color: _overTrash ? Colors.redAccent : Colors.black87,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
              child: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ),
      );

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
                  final height = MediaQuery.sizeOf(context).height;
                  setState(() {
                    item.position += details.focalPointDelta;
                    final next = item.gestureStartScale * details.scale;
                    item.scale = next.isFinite ? next.clamp(.08, 20.0).toDouble() : item.scale;
                    item.rotation = item.gestureStartRotation + details.rotation;
                    _overTrash = details.focalPoint.dy > height - 125;
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
              child: _overlayBody(item, selected),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayBody(_StoryOverlay item, bool selected) {
    if (item.photo != null) {
      return Container(
        width: 168,
        height: 216,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: selected && !_movingOverlay ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(item.photo!, fit: BoxFit.cover, filterQuality: FilterQuality.high, gaplessPlayback: true),
      );
    }
    if (item.isEmoji) {
      return Text(item.text ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 58));
    }
    if (item.targetUserId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(18),
          border: selected && !_movingOverlay ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Text(
          item.text ?? '',
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: selected && !_movingOverlay
          ? BoxDecoration(border: Border.all(color: Colors.white70), borderRadius: BorderRadius.circular(8))
          : null,
      child: Text(
        item.text ?? '',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: item.color,
          fontFamily: item.fontFamily,
          fontSize: 34,
          height: 1.05,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 1))],
        ),
      ),
    );
  }
}

class _MentionPickerSheet extends StatefulWidget {
  const _MentionPickerSheet();

  @override
  State<_MentionPickerSheet> createState() => _MentionPickerSheetState();
}

class _MentionPickerSheetState extends State<_MentionPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
          ),
          const Text('Bahset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Kullanıcı ara',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFF191C21),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').limit(120).snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!.docs.where((doc) {
                  if (doc.id == me) return false;
                  final data = doc.data();
                  final display = (data['displayName'] ?? data['username'] ?? data['email'] ?? '').toString().toLowerCase();
                  return _query.isEmpty || display.contains(_query);
                }).toList();
                if (users.isEmpty) return const Center(child: Text('Kullanıcı bulunamadı', style: TextStyle(color: Colors.white60)));
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, index) {
                    final doc = users[index];
                    final data = doc.data();
                    final name = (data['displayName'] ?? data['username'] ?? data['email'] ?? 'Kullanıcı').toString();
                    final username = (data['username'] ?? '').toString();
                    final label = username.trim().isNotEmpty ? username.trim().replaceFirst('@', '') : name.replaceAll(' ', '');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF24272D),
                        backgroundImage: (data['photoUrl'] ?? '').toString().isEmpty ? null : NetworkImage((data['photoUrl']).toString()),
                        child: (data['photoUrl'] ?? '').toString().isEmpty ? const Icon(Icons.person_outline) : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: username.isEmpty ? null : Text('@$username'),
                      onTap: () => Navigator.pop(context, _MentionChoice(userId: doc.id, label: label)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MentionChoice {
  final String userId;
  final String label;
  const _MentionChoice({required this.userId, required this.label});
}

class _LayoutPreview extends StatelessWidget {
  final int count;
  const _LayoutPreview({required this.count});

  @override
  Widget build(BuildContext context) {
    final rows = (count / 2).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: List.generate(
          rows,
          (_) => Expanded(
            child: Row(
              children: List.generate(
                2,
                (_) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      border: Border.all(color: Colors.white24),
                    ),
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

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xB3121418),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 58,
            height: 50,
            child: Opacity(
              opacity: disabled ? .35 : 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 9.2, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ModePanel extends StatelessWidget {
  final String title;
  final VoidCallback done;
  final Widget child;
  const _ModePanel({required this.title, required this.done, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xD916181D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
                InkWell(
                  onTap: done,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.check_rounded, size: 20)),
                ),
              ],
            ),
            child,
          ],
        ),
      );
}

class _StoryOverlay {
  final String? text;
  final bool isEmoji;
  final String? fontFamily;
  final Color color;
  final File? photo;
  final String? targetUserId;
  Offset position;
  double scale, rotation, gestureStartScale, gestureStartRotation;

  _StoryOverlay._({
    required this.text,
    required this.isEmoji,
    required this.fontFamily,
    required this.color,
    required this.photo,
    required this.targetUserId,
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
        targetUserId: null,
        position: position,
      );

  factory _StoryOverlay.mention({
    required String text,
    required String targetUserId,
    required Offset position,
  }) => _StoryOverlay._(
        text: text,
        isEmoji: false,
        fontFamily: 'sans-serif-medium',
        color: Colors.black,
        photo: null,
        targetUserId: targetUserId,
        position: position,
      );

  factory _StoryOverlay.photo({required File photo, required Offset position}) => _StoryOverlay._(
        text: null,
        isEmoji: false,
        fontFamily: null,
        color: Colors.white,
        photo: photo,
        targetUserId: null,
        position: position,
      );

  _StoryOverlay copyWith({required Offset position}) => _StoryOverlay._(
        text: text,
        isEmoji: isEmoji,
        fontFamily: fontFamily,
        color: color,
        photo: photo,
        targetUserId: targetUserId,
        position: position,
        scale: scale,
        rotation: rotation,
      );
}

class _FontOption {
  final String label, family;
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
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: onTap == null ? Colors.white30 : Colors.white),
          ),
        ),
      );
}
