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

  int? _selectedIndex;
  bool _sharing = false;

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

  Future<void> _addText() async {
    final controller = TextEditingController();
    var font = _fonts.first;
    var color = Colors.white;

    final result = await showModalBottomSheet<_TextResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111318),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yazı ekle',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 180,
                minLines: 1,
                maxLines: 4,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: font.family,
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  hintText: 'Bir şey yaz…',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fonts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final item = _fonts[index];
                    final selected = item.family == font.family;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(
                        item.label,
                        style: TextStyle(fontFamily: item.family),
                      ),
                      onSelected: (_) => setSheetState(() => font = item),
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
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setSheetState(() => color = item),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == item
                                  ? Colors.white
                                  : Colors.white24,
                              width: color == item ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      Navigator.pop(
                        sheetContext,
                        _TextResult(text, font.family, color),
                      );
                    },
                    child: const Text('Ekle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    controller.dispose();
    if (result == null || !mounted) return;

    final size = MediaQuery.sizeOf(context);
    setState(() {
      _overlays.add(
        _StoryOverlay.text(
          text: result.text,
          fontFamily: result.fontFamily,
          color: result.color,
          position: Offset(size.width * .18, size.height * .42),
        ),
      );
      _selectedIndex = _overlays.length - 1;
    });
  }

  Future<void> _addEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111318),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emoji ekle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
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
                onTap: () => Navigator.pop(
                  sheetContext,
                  _emojiChoices[index],
                ),
                child: Center(
                  child: Text(
                    _emojiChoices[index],
                    style: const TextStyle(fontSize: 27),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (emoji == null || !mounted) return;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _overlays.add(
        _StoryOverlay.emoji(
          text: emoji,
          position: Offset(size.width * .38, size.height * .44),
        ),
      );
      _selectedIndex = _overlays.length - 1;
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
    setState(() => _selectedIndex = null);
    await WidgetsBinding.instance.endOfFrame;

    final boundary = _canvasKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Story görüntüsü hazırlanamadı.');

    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.5, 3.0);
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
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
      Navigator.pop(context, true);
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
        if (rendered != null && await rendered.exists()) await rendered.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundAction(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context, false),
                      ),
                      const Spacer(),
                      _RoundAction(
                        icon: Icons.text_fields_rounded,
                        onTap: _addText,
                      ),
                      const SizedBox(width: 9),
                      _RoundAction(
                        icon: Icons.emoji_emotions_outlined,
                        onTap: _addEmoji,
                      ),
                      if (_selectedIndex != null) ...[
                        const SizedBox(width: 9),
                        _RoundAction(
                          icon: Icons.delete_outline_rounded,
                          onTap: _removeSelected,
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (_selectedIndex != null)
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
        ],
      ),
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
            item.scale = (item.gestureStartScale * details.scale).clamp(.45, 4.5);
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

class _TextResult {
  final String text;
  final String fontFamily;
  final Color color;
  const _TextResult(this.text, this.fontFamily, this.color);
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

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
            child: Icon(icon, color: Colors.white),
          ),
        ),
      );
}
