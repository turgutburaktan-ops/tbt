import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/ai_service.dart';
import 'create_post_screen.dart';

enum AiEditAction {
  autoEnhance,
  fixLight,
  removePeople,
  removeObject,
  customPrompt,
}

class AiEditScreen extends StatefulWidget {
  final String originalImagePath;
  final String? captureMode;

  const AiEditScreen({
    super.key,
    required this.originalImagePath,
    this.captureMode,
  });

  @override
  State<AiEditScreen> createState() => _AiEditScreenState();
}

class _AiEditScreenState extends State<AiEditScreen> {
  late String _currentImagePath;
  bool _processing = false;
  AiEditAction? _activeAction;
  Offset? _removePoint;
  bool _selectingObject = false;
  Size? _imagePixelSize;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.originalImagePath;
    _loadImageSize(_currentImagePath);
  }

  void _loadImageSize(String path) async {
    try {
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (!mounted || decoded == null) return;
      setState(() {
        _imagePixelSize = Size(
          decoded.width.toDouble(),
          decoded.height.toDouble(),
        );
      });
    } catch (_) {}
  }

  Rect _imageRect(Size viewport) {
    final source = _imagePixelSize;
    if (source == null || source.isEmpty || viewport.isEmpty) {
      return Offset.zero & viewport;
    }
    final fitted = applyBoxFit(BoxFit.contain, source, viewport).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & viewport);
  }

  Future<void> _runEdit(
    AiEditAction action, {
    Offset? normalizedPoint,
    String? prompt,
  }) async {
    if (_processing) return;

    setState(() {
      _processing = true;
      _activeAction = action;
    });

    try {
      final result = await AiService.editPhoto(
        imagePath: _currentImagePath,
        action: _actionName(action),
        pointX: normalizedPoint?.dx,
        pointY: normalizedPoint?.dy,
        prompt: prompt,
        mode: widget.captureMode,
      );

      if (!mounted) return;
      setState(() {
        _currentImagePath = result.outputPath;
        _processing = false;
        _activeAction = null;
        _selectingObject = false;
        _removePoint = null;
      });
      _loadImageSize(result.outputPath);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _activeAction = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI düzenleme başarısız: ${_friendlyError(e)}')),
      );
    }
  }

  String _actionName(AiEditAction action) {
    switch (action) {
      case AiEditAction.autoEnhance:
        return 'auto_enhance';
      case AiEditAction.fixLight:
        return 'fix_light';
      case AiEditAction.removePeople:
        return 'remove_people';
      case AiEditAction.removeObject:
        return 'remove_object';
      case AiEditAction.customPrompt:
        return 'custom_prompt';
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('404')) {
      return 'AI düzenleme servisi sunucuda henüz aktif değil.';
    }
    if (text.toLowerCase().contains('timeout')) {
      return 'Sunucu yanıtı çok uzun sürdü.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  void _beginRemoveObject() {
    if (_processing) return;
    setState(() {
      _selectingObject = true;
      _removePoint = null;
    });
  }

  Future<void> _openAiPrompt() async {
    if (_processing) return;
    final controller = TextEditingController();
    final prompt = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1113),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✨ AI’ye Yaz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fotoğrafta ne değişmesini istediğini yaz. AI, istemediğin alanları mümkün olduğunca korur.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                maxLength: 600,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Örn: Gökyüzünü daha dramatik yap ama binayı ve insanları değiştirme.',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A2029),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) Navigator.pop(context, text);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB7BCC2),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text(
                    'AI ile Uygula',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (prompt != null && prompt.trim().isNotEmpty && mounted) {
      await _runEdit(AiEditAction.customPrompt, prompt: prompt);
    }
  }

  void _resetOriginal() {
    if (_processing) return;
    setState(() {
      _currentImagePath = widget.originalImagePath;
      _removePoint = null;
      _selectingObject = false;
    });
    _loadImageSize(widget.originalImagePath);
  }

  Future<void> _continueToShare() async {
    if (_processing) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(initialImagePath: _currentImagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = File(_currentImagePath);
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07090D),
        elevation: 0,
        title: const Text(
          'AI Düzenle',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _processing ? null : _resetOriginal,
            child: const Text(
              'Orijinal',
              style: TextStyle(color: Color(0xFFB7BCC2)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: Colors.black,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final imageRect = _imageRect(constraints.biggest);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: !_selectingObject || _processing
                              ? null
                              : (details) {
                                  if (!imageRect.contains(
                                    details.localPosition,
                                  )) {
                                    return;
                                  }
                                  final normalized = Offset(
                                    ((details.localPosition.dx -
                                                imageRect.left) /
                                            imageRect.width)
                                        .clamp(0.0, 1.0),
                                    ((details.localPosition.dy -
                                                imageRect.top) /
                                            imageRect.height)
                                        .clamp(0.0, 1.0),
                                  );
                                  setState(() => _removePoint = normalized);
                                },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(imageFile, fit: BoxFit.contain),
                              if (_selectingObject)
                                Container(color: Colors.black.withOpacity(.10)),
                              if (_selectingObject && _removePoint != null)
                                Positioned(
                                  left:
                                      imageRect.left +
                                      _removePoint!.dx * imageRect.width -
                                      26,
                                  top:
                                      imageRect.top +
                                      _removePoint!.dy * imageRect.height -
                                      26,
                                  child: const IgnorePointer(
                                    child: _TargetMarker(),
                                  ),
                                ),
                              if (_processing)
                                Container(
                                  color: Colors.black.withOpacity(.50),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(
                                          color: Color(0xFFB7BCC2),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          _processingText(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (_selectingObject)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121416),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        color: Color(0xFFB7BCC2),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Kaldırmak istediğin nesnenin üzerine dokun.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: _removePoint == null
                            ? null
                            : () => _runEdit(
                                AiEditAction.removeObject,
                                normalizedPoint: _removePoint,
                              ),
                        child: const Text('Kaldır'),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: 104,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _EditTool(
                    icon: Icons.auto_awesome,
                    label: 'Otomatik',
                    onTap: () => _runEdit(AiEditAction.autoEnhance),
                  ),
                  _EditTool(
                    icon: Icons.light_mode_outlined,
                    label: 'Işık',
                    onTap: () => _runEdit(AiEditAction.fixLight),
                  ),
                  _EditTool(
                    icon: Icons.groups_2_outlined,
                    label: 'İnsanları\nKaldır',
                    onTap: () => _runEdit(AiEditAction.removePeople),
                  ),
                  _EditTool(
                    icon: Icons.auto_fix_high,
                    label: 'Nesne\nKaldır',
                    onTap: _beginRemoveObject,
                  ),
                  _EditTool(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'AI’ye\nYaz',
                    onTap: _openAiPrompt,
                  ),
                  _EditTool(
                    icon: Icons.undo_rounded,
                    label: 'Orijinale\nDön',
                    onTap: _resetOriginal,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _processing ? null : _continueToShare,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB7BCC2),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Paylaşmaya Devam Et',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _processingText() {
    switch (_activeAction) {
      case AiEditAction.autoEnhance:
        return 'AI fotoğrafı iyileştiriyor...';
      case AiEditAction.fixLight:
        return 'AI ışığı düzeltiyor...';
      case AiEditAction.removePeople:
        return 'AI arka plandaki insanları kaldırıyor...';
      case AiEditAction.removeObject:
        return 'AI nesneyi kaldırıyor...';
      case AiEditAction.customPrompt:
        return 'AI tarifini uyguluyor...';
      case null:
        return 'AI çalışıyor...';
    }
  }
}

class _EditTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _EditTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF121416),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFB7BCC2), size: 26),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetMarker extends StatelessWidget {
  const _TargetMarker();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB7BCC2), width: 3),
        color: Colors.black.withOpacity(.25),
      ),
      child: const Icon(Icons.close_rounded, color: Color(0xFFB7BCC2)),
    );
  }
}
