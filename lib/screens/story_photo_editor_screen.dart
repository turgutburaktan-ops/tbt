import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../services/story_context_link_service.dart';
import '../services/story_service.dart';
import 'story_context_template_picker.dart';
import 'story_music_picker.dart';

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
  final List<_OverlayItem> _items = <_OverlayItem>[];
  final List<_Stroke> _strokes = <_Stroke>[];
  final List<File?> _layoutSlots = <File?>[];

  int? _selected;
  int _layoutCount = 0;
  StoryContextTemplateSelection? _contextTemplate;
  StoryMusicSelection? _musicSelection;
  bool _sharing = false;
  bool _exporting = false;
  bool _editingText = false;
  bool _drawing = false;
  bool _editingBackground = false;
  bool _moving = false;
  bool _overTrash = false;
  _Stroke? _activeStroke;

  double _bgScale = 1;
  double _bgRotation = 0;
  double _bgStartScale = 1;
  double _bgStartRotation = 0;
  Offset _bgOffset = Offset.zero;

  String _font = 'sans-serif';
  Color _textColor = Colors.white;
  Color _drawColor = Colors.white;

  static const List<String> _fonts = <String>[
    'sans-serif',
    'serif',
    'monospace',
    'sans-serif-medium',
    'sans-serif-light',
  ];
  static const List<String> _fontLabels = <String>[
    'Modern',
    'Klasik',
    'Daktilo',
    'Yuvarlak',
    'İnce',
  ];
  static const List<Color> _colors = <Color>[
    Colors.white,
    Colors.black,
    Color(0xFFFFE25C),
    Color(0xFFFF5C8A),
    Color(0xFF74E7FF),
    Color(0xFFC79AFF),
    Color(0xFF8EFFB5),
  ];
  static const List<String> _emojis = <String>[
    '😂','❤️','😍','🔥','🥰','😭','👏','✨','😎','🥳',
    '🤍','💜','💯','🙌','🤩','😋','🌟','🎉','📸','📍',
    '✈️','☕','🍕','🌊','🌅','🎶','⚡','🫶','🤝','😜',
  ];

  @override
  void dispose() {
    _textFocus.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _finishMode() {
    if (_editingText && _textController.text.trim().isNotEmpty) {
      _commitText();
      return;
    }
    _textFocus.unfocus();
    if (!mounted) return;
    setState(() {
      _editingText = false;
      _drawing = false;
      _editingBackground = false;
      _selected = null;
      _activeStroke = null;
      _moving = false;
      _overTrash = false;
    });
  }

  void _openText() {
    if (_sharing) return;
    setState(() {
      _editingText = true;
      _drawing = false;
      _editingBackground = false;
      _selected = null;
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
      _textController.clear();
    });
  }

  void _commitText() {
    final String text = _textController.text.trim();
    if (text.isEmpty) {
      _cancelText();
      return;
    }
    final Size s = MediaQuery.sizeOf(context);
    setState(() {
      _items.add(
        _OverlayItem.text(
          text,
          Offset(s.width * .5, s.height * .43),
          _font,
          _textColor,
        ),
      );
      _selected = _items.length - 1;
      _editingText = false;
      _textController.clear();
    });
    _textFocus.unfocus();
  }

  Future<void> _openMusicPicker() async {
    if (_sharing) return;
    _finishMode();
    final StoryMusicSelection? selected = await showModalBottomSheet<StoryMusicSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StoryMusicPicker(),
    );
    if (!mounted || selected == null) return;

    final Size s = MediaQuery.sizeOf(context);
    setState(() {
      _musicSelection = selected;
      _items.removeWhere((item) => item.music != null);
      _items.add(
        _OverlayItem.music(
          selected,
          Offset(s.width * .5, s.height * .23),
        ),
      );
      _selected = _items.length - 1;
    });
  }

  Future<void> _openEmojiPicker() async {
    if (_sharing) return;
    _finishMode();
    final String? emoji = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Emoji',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _emojis.length,
                itemBuilder: (_, int index) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(sheetContext, _emojis[index]),
                    child: Center(
                      child: Text(
                        _emojis[index],
                        style: const TextStyle(fontSize: 34),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || emoji == null) return;
    final Size s = MediaQuery.sizeOf(context);
    setState(() {
      _items.add(
        _OverlayItem.emoji(
          emoji,
          Offset(s.width * .5, s.height * .43),
        ),
      );
      _selected = _items.length - 1;
    });
  }

  Future<void> _addPhotos() async {
    if (_sharing) return;
    final List<XFile> picked = await _picker.pickMultiImage();
    if (!mounted || picked.isEmpty) return;
    final Size s = MediaQuery.sizeOf(context);
    final int remaining = math.max(
      0,
      10 - _items.where((e) => e.photo != null).length,
    );
    setState(() {
      for (final XFile x in picked.take(remaining)) {
        _items.add(
          _OverlayItem.photo(
            File(x.path),
            Offset(s.width * .5, s.height * .43),
          ),
        );
      }
      if (_items.isNotEmpty) _selected = _items.length - 1;
    });
  }

  Future<void> _openMentionPicker() async {
    if (_sharing) return;
    _finishMode();
    final _Mention? choice = await showModalBottomSheet<_Mention>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const _MentionSheet(),
    );
    if (!mounted || choice == null) return;
    final Size s = MediaQuery.sizeOf(context);
    setState(() {
      _items.add(
        _OverlayItem.mention(
          '@${choice.label}',
          choice.uid,
          Offset(s.width * .5, s.height * .46),
        ),
      );
      _selected = _items.length - 1;
    });
  }

  Future<void> _openContextTemplates() async {
    if (_sharing) return;
    _finishMode();
    final StoryContextTemplateSelection? selected =
        await Navigator.push<StoryContextTemplateSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => const StoryContextTemplatePicker(),
      ),
    );
    if (!mounted || selected == null) return;

    final Size s = MediaQuery.sizeOf(context);
    setState(() {
      _contextTemplate = selected;
      _layoutCount = selected.slotCount;
      _layoutSlots
        ..clear()
        ..addAll(List<File?>.filled(selected.slotCount, null));
      if (selected.contextType != 'free' &&
          selected.contextName.trim().isNotEmpty) {
        _items.add(
          _OverlayItem.context(
            '${_contextIcon(selected.contextType)} ${selected.contextName}',
            Offset(s.width * .5, s.height * .17),
          ),
        );
      }
      _items.add(
        _OverlayItem.context(
          selected.templateTitle,
          Offset(s.width * .5, s.height * .84),
          compact: true,
        ),
      );
      _selected = _items.length - 1;
    });
  }

  String _contextIcon(String type) {
    switch (type) {
      case 'event': return '🎟️';
      case 'venue': return '📍';
      case 'spot': return '🗺️';
      default: return '✨';
    }
  }

  Future<void> _chooseLayout() async {
    if (_sharing) return;
    _finishMode();
    final int? count = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Yerleşim',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Her bölmeye ayrı fotoğraf ekle.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  for (final int n in <int>[2, 4, 8])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, n),
                          child: Text('$n’li'),
                        ),
                      ),
                    ),
                ],
              ),
              if (_layoutCount > 0)
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, 0),
                  child: const Text('Yerleşimi kaldır'),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || count == null) return;
    setState(() {
      _contextTemplate = null;
      _layoutCount = count;
      _layoutSlots
        ..clear()
        ..addAll(List<File?>.filled(count, null));
      _editingBackground = false;
    });
  }

  Future<void> _pickLayoutPhoto(int index) async {
    if (_sharing || _exporting || index < 0 || index >= _layoutSlots.length) {
      return;
    }
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (!mounted || picked == null) return;
    setState(() => _layoutSlots[index] = File(picked.path));
  }

  void _toggleDraw() {
    if (_sharing) return;
    setState(() {
      _drawing = !_drawing;
      _editingText = false;
      _editingBackground = false;
      _selected = null;
    });
  }

  void _toggleBackground() {
    if (_sharing || _layoutCount > 0) return;
    setState(() {
      _editingBackground = !_editingBackground;
      _drawing = false;
      _editingText = false;
      _selected = null;
    });
  }

  void _removeSelected() {
    final int? i = _selected;
    if (i == null || i < 0 || i >= _items.length) return;
    setState(() {
      if (_items[i].music != null) _musicSelection = null;
      _items.removeAt(i);
      _selected = null;
      _moving = false;
      _overTrash = false;
    });
  }

  Future<File> _renderStory() async {
    setState(() {
      _selected = null;
      _editingText = false;
      _drawing = false;
      _editingBackground = false;
      _exporting = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    final RenderObject? object = _canvasKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw Exception('Story hazırlanamadı.');
    }
    try {
      final ui.Image image = await object.toImage(
        pixelRatio: math.max(3.0, MediaQuery.devicePixelRatioOf(context)).toDouble(),
      );
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw Exception('Story oluşturulamadı.');
      final File file = File(
        '${Directory.systemTemp.path}/tbt_story_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
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
      final List<String> mentions = _items
          .map((e) => e.targetUserId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      await StoryService.instance.createStory(rendered, mentionedUserIds: mentions);
      final StoryContextTemplateSelection? t = _contextTemplate;
      if (t != null) {
        await StoryContextLinkService.instance.attachToLatestOwnStory(
          contextType: t.contextType,
          contextId: t.contextId,
          contextName: t.contextName,
          templateId: t.templateId,
          templateTitle: t.templateTitle,
          slotCount: t.slotCount,
        );
      }
      final StoryMusicSelection? music = _musicSelection;
      if (music != null) {
        await StoryContextLinkService.instance.attachMusicToLatestOwnStory(
          trackId: music.trackId,
          title: music.title,
          artist: music.artist,
          artworkUrl: music.artworkUrl,
          previewUrl: music.previewUrl,
          startMs: music.startMs,
          durationMs: music.clipDurationMs,
          stickerStyle: music.stickerStyle,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      try {
        if (rendered != null && await rendered.exists()) await rendered.delete();
      } catch (_) {}
    }
  }

  Widget _background() {
    if (_layoutCount > 0) return _layout();
    return ColoredBox(
      color: Colors.black,
      child: Transform.translate(
        offset: _bgOffset,
        child: Transform.rotate(
          angle: _bgRotation,
          child: Transform.scale(
            scale: _bgScale,
            child: Image.file(
              widget.photo,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout() {
    final int rows = (_layoutCount / 2).ceil();
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: List<Widget>.generate(rows, (int row) {
          return Expanded(
            child: Row(
              children: List<Widget>.generate(2, (int column) {
                final int index = row * 2 + column;
                if (index >= _layoutCount) return const Expanded(child: SizedBox());
                final File? file = _layoutSlots[index];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: const Color(0xFF111318),
                      child: InkWell(
                        onTap: _exporting ? null : () => _pickLayoutPhoto(index),
                        child: file == null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.add_rounded, size: 36, color: Colors.white70),
                                    const SizedBox(height: 4),
                                    Text('${index + 1}. fotoğraf', style: const TextStyle(color: Colors.white54)),
                                  ],
                                ),
                              )
                            : Image.file(
                                file,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sharing,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (_layoutCount > 0)
                      _background()
                    else
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _finishMode,
                        child: _background(),
                      ),
                    IgnorePointer(
                      ignoring: !_drawing,
                      child: CustomPaint(painter: _Painter(_strokes, _activeStroke)),
                    ),
                    ...List<Widget>.generate(_items.length, _buildItem),
                  ],
                ),
              ),
            ),
            if (_editingBackground)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _finishMode,
                  onScaleStart: (_) {
                    _bgStartScale = _bgScale;
                    _bgStartRotation = _bgRotation;
                  },
                  onScaleUpdate: (ScaleUpdateDetails d) {
                    setState(() {
                      _bgOffset += d.focalPointDelta;
                      _bgScale = (_bgStartScale * d.scale).clamp(.05, 30.0).toDouble();
                      _bgRotation = _bgStartRotation + d.rotation;
                    });
                  },
                ),
              ),
            if (_drawing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _finishMode,
                  onPanStart: (DragStartDetails d) {
                    setState(() => _activeStroke = _Stroke(_drawColor, 5.5, <Offset>[d.localPosition]));
                  },
                  onPanUpdate: (DragUpdateDetails d) {
                    setState(() => _activeStroke?.points.add(d.localPosition));
                  },
                  onPanEnd: (_) {
                    final _Stroke? stroke = _activeStroke;
                    setState(() {
                      if (stroke != null && stroke.points.length > 1) _strokes.add(stroke);
                      _activeStroke = null;
                    });
                  },
                ),
              ),
            if (!_editingText) _chrome(),
            if (_editingText) _textComposer(),
            if (_moving) _trash(),
          ],
        ),
      ),
    );
  }

  Widget _chrome() {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topLeft,
                child: _Round(
                  icon: Icons.close_rounded,
                  onTap: _sharing ? null : () => Navigator.pop(context, false),
                ),
              ),
              if (!_drawing && !_editingBackground)
                Align(
                  alignment: Alignment.topRight,
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        _Tool(Icons.auto_awesome_mosaic_outlined, 'Şablon', _openContextTemplates),
                        const SizedBox(height: 7),
                        _Tool(Icons.text_fields_rounded, 'Yazı', _openText),
                        const SizedBox(height: 7),
                        _Tool(Icons.music_note_rounded, 'Müzik', _openMusicPicker),
                        const SizedBox(height: 7),
                        _Tool(Icons.emoji_emotions_outlined, 'Emoji', _openEmojiPicker),
                        const SizedBox(height: 7),
                        _Tool(Icons.alternate_email_rounded, 'Bahset', _openMentionPicker),
                        const SizedBox(height: 7),
                        _Tool(Icons.grid_view_rounded, 'Yerleşim', _chooseLayout),
                        const SizedBox(height: 7),
                        _Tool(Icons.add_photo_alternate_outlined, 'Fotoğraf', _addPhotos),
                        const SizedBox(height: 7),
                        _Tool(Icons.draw_outlined, 'Çiz', _toggleDraw),
                        const SizedBox(height: 7),
                        _Tool(Icons.crop_free_rounded, 'Kadraj', _toggleBackground, disabled: _layoutCount > 0),
                      ],
                    ),
                  ),
                ),
              if (_drawing)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(child: Text('Çizim', style: TextStyle(fontWeight: FontWeight.w900))),
                            IconButton(onPressed: _finishMode, icon: const Icon(Icons.check)),
                          ],
                        ),
                        Wrap(
                          spacing: 5,
                          children: _colors.map((Color c) {
                            return GestureDetector(
                              onTap: () => setState(() => _drawColor = c),
                              child: CircleAvatar(radius: 12, backgroundColor: c),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_editingBackground)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 155,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(child: Text('Kadraj', style: TextStyle(fontWeight: FontWeight.w900))),
                            IconButton(onPressed: _finishMode, icon: const Icon(Icons.check)),
                          ],
                        ),
                        const Text('Sürükle ve iki parmakla ölçekle', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              if (_selected != null && !_moving && !_drawing && !_editingBackground)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 70),
                    child: IconButton.filled(onPressed: _removeSelected, icon: const Icon(Icons.delete_outline)),
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
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: Text(_sharing ? 'Paylaşılıyor…' : 'Story’ni paylaş', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textComposer() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _commitText,
        child: ColoredBox(
          color: Colors.black45,
          child: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      TextButton(onPressed: _cancelText, child: const Text('Vazgeç')),
                      const Spacer(),
                      FilledButton(onPressed: _commitText, child: const Text('Bitti')),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocus,
                      autofocus: true,
                      maxLength: 180,
                      maxLines: 5,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: _font, color: _textColor, fontSize: 34, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(border: InputBorder.none, counterText: '', hintText: 'Bir şey yaz…'),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _fonts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, int i) {
                      return ChoiceChip(
                        label: Text(_fontLabels[i]),
                        selected: _font == _fonts[i],
                        onSelected: (_) => setState(() => _font = _fonts[i]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _colors.map((Color c) {
                    return GestureDetector(
                      onTap: () => setState(() => _textColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: _textColor == c ? Colors.white : Colors.white38, width: 2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int i) {
    final _OverlayItem x = _items[i];
    final bool expandedHitArea = x.isPlainText;
    return Positioned(
      left: x.position.dx,
      top: x.position.dy,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = i),
          onScaleStart: (_) {
            x.startScale = x.scale;
            x.startRotation = x.rotation;
            setState(() {
              _selected = i;
              _moving = true;
            });
          },
          onScaleUpdate: (ScaleUpdateDetails d) {
            setState(() {
              x.position += d.focalPointDelta;
              x.scale = (x.startScale * d.scale).clamp(.08, 12.0).toDouble();
              x.rotation = x.startRotation + d.rotation;
              _overTrash = d.focalPoint.dy > MediaQuery.sizeOf(context).height - 125;
            });
          },
          onScaleEnd: (_) {
            if (_overTrash) {
              _removeSelected();
            } else {
              setState(() {
                _moving = false;
                _overTrash = false;
              });
            }
          },
          child: Padding(
            padding: expandedHitArea
                ? const EdgeInsets.symmetric(horizontal: 38, vertical: 30)
                : EdgeInsets.zero,
            child: Transform.rotate(
              angle: x.rotation,
              child: Transform.scale(
                scale: x.scale,
                child: _itemBody(x, i == _selected),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemBody(_OverlayItem x, bool selected) {
    if (x.music != null) return _musicSticker(x.music!);
    if (x.photo != null) {
      return Container(
        width: 168,
        height: 216,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: selected && !_moving ? Border.all(color: Colors.white, width: 2) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(x.photo!, fit: BoxFit.cover),
      );
    }
    if (x.emoji) {
      return Text(x.text ?? '', style: const TextStyle(fontSize: 62));
    }
    if (x.targetUserId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Text(x.text ?? '', style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900)),
      );
    }
    if (x.context) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(18)),
        child: Text(x.text ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: x.compact ? 14 : 17, fontWeight: FontWeight.w900)),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, minHeight: 52, maxWidth: 320),
      child: Center(
        child: Text(
          x.text ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: x.font,
            color: x.color,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 5)],
          ),
        ),
      ),
    );
  }

  Widget _musicSticker(StoryMusicSelection music) {
    if (music.stickerStyle == 'title') {
      return Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(music.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      );
    }

    if (music.stickerStyle == 'card') {
      return Container(
        width: 245,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xE6121418),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)],
                ),
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(music.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(music.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: _musicShader,
            child: Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text('${music.title} · ${music.artist}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  static Shader _musicShader(Rect bounds) {
    return const LinearGradient(
      colors: <Color>[Color(0xFF38E8FF), Color(0xFF4A7DFF), Color(0xFF9B4DFF)],
    ).createShader(bounds);
  }

  Widget _trash() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: Center(
          child: CircleAvatar(
            radius: _overTrash ? 34 : 28,
            backgroundColor: _overTrash ? Colors.redAccent : Colors.black87,
            child: const Icon(Icons.delete_outline),
          ),
        ),
      ),
    );
  }
}

class _MentionSheet extends StatefulWidget {
  const _MentionSheet();

  @override
  State<_MentionSheet> createState() => _MentionSheetState();
}

class _MentionSheetState extends State<_MentionSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final String? me = FirebaseAuth.instance.currentUser?.uid;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Bahset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              autofocus: true,
              onChanged: (String value) => setState(() => q = value.toLowerCase()),
              decoration: const InputDecoration(hintText: 'Kullanıcı ara', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').limit(120).snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((doc) {
                  if (doc.id == me) return false;
                  final data = doc.data();
                  final String name = (data['displayName'] ?? data['username'] ?? '').toString().toLowerCase();
                  return q.isEmpty || name.contains(q);
                }).toList();
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, int i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final String name = (data['displayName'] ?? data['username'] ?? 'Kullanıcı').toString();
                    final String user = (data['username'] ?? '').toString();
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(name),
                      subtitle: user.isEmpty ? null : Text('@$user'),
                      onTap: () {
                        Navigator.pop(
                          context,
                          _Mention(doc.id, user.isEmpty ? name.replaceAll(' ', '') : user.replaceFirst('@', '')),
                        );
                      },
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

class _Mention {
  final String uid;
  final String label;
  const _Mention(this.uid, this.label);
}

class _OverlayItem {
  String? text;
  File? photo;
  String? targetUserId;
  String? font;
  StoryMusicSelection? music;
  Color color;
  bool emoji;
  bool context;
  bool compact;
  Offset position;
  double scale;
  double rotation;
  double startScale;
  double startRotation;

  _OverlayItem({
    this.text,
    this.photo,
    this.targetUserId,
    this.font,
    this.music,
    this.color = Colors.white,
    this.emoji = false,
    this.context = false,
    this.compact = false,
    required this.position,
    this.scale = 1,
    this.rotation = 0,
    this.startScale = 1,
    this.startRotation = 0,
  });

  bool get isPlainText => photo == null && !emoji && targetUserId == null && !context && music == null;

  factory _OverlayItem.text(String text, Offset position, String font, Color color) {
    return _OverlayItem(text: text, position: position, font: font, color: color);
  }

  factory _OverlayItem.emoji(String text, Offset position) {
    return _OverlayItem(text: text, position: position, emoji: true);
  }

  factory _OverlayItem.photo(File file, Offset position) {
    return _OverlayItem(photo: file, position: position);
  }

  factory _OverlayItem.mention(String text, String userId, Offset position) {
    return _OverlayItem(text: text, targetUserId: userId, position: position);
  }

  factory _OverlayItem.context(String text, Offset position, {bool compact = false}) {
    return _OverlayItem(text: text, position: position, context: true, compact: compact);
  }

  factory _OverlayItem.music(StoryMusicSelection music, Offset position) {
    return _OverlayItem(music: music, position: position);
  }
}

class _Stroke {
  final Color color;
  final double width;
  final List<Offset> points;
  _Stroke(this.color, this.width, this.points);
}

class _Painter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? active;
  const _Painter(this.strokes, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Stroke stroke in <_Stroke>[...strokes, if (active != null) active!]) {
      if (stroke.points.length < 2) continue;
      final Paint paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final Path path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final Offset point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) => true;
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback tap;
  final bool disabled;

  const _Tool(this.icon, this.label, this.tap, {this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB3121418),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: disabled ? null : tap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 58,
          height: 50,
          child: Opacity(
            opacity: disabled ? .35 : 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 21),
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _Round({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon)),
      ),
    );
  }
}
