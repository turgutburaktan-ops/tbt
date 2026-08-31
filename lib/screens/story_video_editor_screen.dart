import 'dart:io';

import 'package:flutter/material.dart';

import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_video_player.dart';

class StoryVideoEditorScreen extends StatefulWidget {
  final File video;

  const StoryVideoEditorScreen({super.key, required this.video});

  @override
  State<StoryVideoEditorScreen> createState() =>
      _StoryVideoEditorScreenState();
}

class _StoryVideoEditorScreenState extends State<StoryVideoEditorScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _sharing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _share() async {
    if (_sharing) return;
    final overlayText = _textController.text.trim();
    if (overlayText.length > 120) {
      _message('Story yazısı en fazla 120 karakter olabilir.');
      return;
    }
    setState(() => _sharing = true);
    try {
      await StoryService.instance.createVideoStory(
        widget.video,
        caption: overlayText,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _message(
        'Story paylaşılamadı: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Story’yi Düzenle'),
        leading: IconButton(
          tooltip: 'Tekrar çek',
          onPressed: _sharing ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppVideoPlayer.file(
                        file: widget.video,
                        autoplay: true,
                        muted: false,
                        loop: true,
                        showControls: true,
                        fit: BoxFit.cover,
                      ),
                      IgnorePointer(
                        child: Center(
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _textController,
                            builder: (_, value, __) {
                              final text = value.text.trim();
                              if (text.isEmpty) return const SizedBox.shrink();
                              return Container(
                                constraints: const BoxConstraints(maxWidth: 300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  text,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 8),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textController,
                    enabled: !_sharing,
                    maxLength: 120,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Story’ye yazı ekle',
                      hintText: 'İstersen videonun üzerine bir şey yaz…',
                      prefixIcon: Icon(Icons.text_fields_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sharing
                              ? null
                              : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tekrar Çek'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _sharing ? null : _share,
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            _sharing ? 'Paylaşılıyor…' : 'Story’yi Paylaş',
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
    );
  }
}
