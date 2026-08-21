import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  final List<_StoryOverlay> _overlays = [];
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  int? _selectedIndex;
  bool _sharing = false;
  _EditorPanel _panel = _EditorPanel.none;
  _FontOption _font = _fonts.first;
  Color _textColor = Colors.white;

  static const _fonts = <_FontOption>[
    _FontOption('Modern', 'sans-serif'),
    _FontOption('Klasik', 'serif'),
    _FontOption('Daktilo', 'monospace'),
    _FontOption('Yuvarlak', 'sans-serif-medium'),
  ];

  static const _emojiChoices = <String>[
    '❤️', '😍', '🔥', '✨', '😂', '🥰', '👏', '🎉',
    '📸', '🌅', '🌙', '⭐', '☕', '🎵', '✈️', '📍',
    '😎', '🤍', '💜', '💫', '🌊', '🏕️', '🌿', '🎂',
  ];

  @override
  void dispose() {
    _textFocus.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _openTextPanel() {
    if (_sharing) return;
    setState(() {
      _panel = _EditorPanel.text;
      _selectedIndex = null;
      _textController.clear();
      _font = _fonts.first;
      _textColor = Colors.white;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  void _openEmojiPanel() {
    if (_sharing) return;
    _textFocus.unfocus();
    setState(() {
      _panel = _EditorPanel.emoji;
      _selectedIndex = null;
    });
  }

  void _closePanel() {
    _textFocus.unfocus();
    setState(() => _panel = _EditorPanel.none);
  }

  void _commitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _overlays.add(
        _StoryOverlay.text(
          text: text,
          fontFamily: _font.family,
          color: _textColor,
          position: Offset(size.width * .18, size.height * .38),
        ),
      );
      _selectedIndex = _overlays.length - 1;
      _panel = _EditorPanel.none;
      _textController.clear();
    });
    _textFocus.unfocus();
  }

  void _addEmoji(String emoji) {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _overlays.add(
        _StoryOverlay.emoji(
          text: emoji,
          position: Offset(size.width * .38, size.height * .42),
        ),
      );
      _selectedIndex = _overlays.length - 1;
      _panel = _EditorPanel.none;
    });
  }

  void _removeSelected() {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _overlays.length) return;
    setState(() {
      _overlays.removeAt(index);
      _selectedIndex = null;
    });
  }

  Future<File> _renderStory() async {
    if (!mounted) throw Exception('Story ekranı kapandı.');
    setState(() {
      _selectedIndex = null;
      _panel = _EditorPanel.none;
    });
    _textFocus.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) throw Exception('Story ekranı kapandı.');

    final renderObject = _canvasKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('Story görüntüsü hazırlanamadı.');
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.5, 3.0);
    final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) throw Exception('Story görüntüsü oluşturulamadı.');

    final file = File(
      '${Directory.systemTemp.path}/tbt_story_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      setState(() => _sharing = false);
    } finally {
      try {
        if (rendered != null && await rendered.exists()) {
          await rendered.delete();
        }
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
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(widget.photo, fit: BoxFit.cover),
                      ...List.generate(
                        _overlays.length,
                        (index) => _buildOverlay(index),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _RoundAction(
                            icon: Icons.close_rounded,
                            onTap: _sharing
                                ? null
                                : () => Navigator.of(context).pop(false),
                          ),
                          const Spacer(),
                          _RoundAction(
                            icon: Icons.text_fields_rounded,
                            onTap: _sharing ? null : _openTextPanel,
                          ),
                          const SizedBox(width: 9),
                          _RoundAction(
                            icon: Icons.emoji_emotions_outlined,
                            onTap: _sharing ? null : _openEmojiPanel,
                          ),
                          if (_selectedIndex != null) ...[
                            const SizedBox(width: 9),
                            _RoundAction(
                              icon: Icons.delete_outline_rounded,
                              onTap: _sharing ? null : _removeSelected,
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      if (_selectedIndex != null && _panel == _EditorPanel.none)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Sürükle • İki parmakla büyüt/küçült',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (_panel == _EditorPanel.none)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _sharing ? null : _share,
                            icon: _sharing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _sharing ? 'Paylaşılıyor…' : 'Story’de Paylaş',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_panel != _EditorPanel.none) _buildEditorPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPanel() {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboard,
      child: Material(
        color: const Color(0xF2111318),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _panel == _EditorPanel.text
                ? _buildTextPanel()
                : _buildEmojiPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildTextPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'Yazı ekle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            IconButton(onPressed: _closePanel, icon: const Icon(Icons.close)),
          ],
        ),
        TextField(
          controller: _textController,
          focusNode: _textFocus,
          maxLength: 180,
          minLines: 1,
          maxLines: 3,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _font.family,
            color: _textColor,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
          decoration: const InputDecoration(
            hintText: 'Bir şey yaz…',
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _fonts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final item = _fonts[index];
              return ChoiceChip(
                selected: item.family == _font.family,
                label: Text(item.label, style: TextStyle(fontFamily: item.family)),
                onSelected: (_) => setState(() => _font = item),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final item in const [
              Colors.white,
              Colors.black,
              Color(0xFFFFE25C),
              Color(0xFFFF5C8A),
              Color(0xFF7FE8FF),
              Color(0xFFC49BFF),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 9),
                child: InkWell(
                  onTap: () => setState(() => _textColor = item),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: item,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == item ? Colors.white : Colors.white24,
                        width: _textColor == item ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            FilledButton(onPressed: _commitText, child: const Text('Ekle')),
          ],
        ),
      ],
    );
  }

  Widget _buildEmojiPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'Emoji ekle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            IconButton(onPressed: _closePanel, icon: const Icon(Icons.close)),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _emojiChoices.length,
          itemBuilder: (_, index) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _addEmoji(_emojiChoices[index]),
            child: Center(
              child: Text(
                _emojiChoices[index],
                style: const TextStyle(fontSize: 27),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(int index) {
    final item = _overlays[index];
    final selected = _selectedIndex == index;
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => _selectedIndex = index),
        onScaleStart: (_) {
          item.gestureStartScale = item.scale;
          setState(() => _selectedIndex = index);
        },
        onScaleUpdate: (details) {
          setState(() {
            item.position += details.focalPointDelta;
            item.scale =
                (item.gestureStartScale * details.scale).clamp(.45, 4.5);
          });
        },
        child: Transform.scale(
          alignment: Alignment.center,
          scale: item.scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: selected
                ? BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Text(
              item.text,
              textAlign: TextAlign.center,
              style: item.isEmoji
                  ? const TextStyle(fontSize: 54)
                  : TextStyle(
                      color: item.color,
                      fontFamily: item.fontFamily,
                      fontSize: 31,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 5,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _EditorPanel { none, text, emoji }

class _StoryOverlay {
  final String text;
  final bool isEmoji;
  final String? fontFamily;
  final Color color;
  Offset position;
  double scale;
  double gestureStartScale;

  _StoryOverlay._({
    required this.text,
    required this.isEmoji,
    required this.fontFamily,
    required this.color,
    required this.position,
    this.scale = 1,
    this.gestureStartScale = 1,
  });

  factory _StoryOverlay.text({
    required String text,
    required String fontFamily,
    required Color color,
    required Offset position,
  }) =>
      _StoryOverlay._(
        text: text,
        isEmoji: false,
        fontFamily: fontFamily,
        color: color,
        position: position,
      );

  factory _StoryOverlay.emoji({
    required String text,
    required Offset position,
  }) =>
      _StoryOverlay._(
        text: text,
        isEmoji: true,
        fontFamily: null,
        color: Colors.white,
        position: position,
      );
}

class _FontOption {
  final String label;
  final String family;
  const _FontOption(this.label, this.family);
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundAction({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              color: onTap == null ? Colors.white30 : Colors.white,
            ),
          ),
        ),
      );
}
