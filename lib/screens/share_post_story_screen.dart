import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/creator_service.dart';
import '../services/content_moderation_service.dart';
import '../widgets/shared_post_card.dart';

class SharePostStoryScreen extends StatefulWidget {
  const SharePostStoryScreen({
    super.key,
    required this.postId,
    this.initialNote = '',
  });
  final String postId;
  final String initialNote;
  @override
  State<SharePostStoryScreen> createState() => _SharePostStoryScreenState();
}

class _SharePostStoryScreenState extends State<SharePostStoryScreen> {
  late final _note = TextEditingController(text: widget.initialNote);
  late final _requestId = FirebaseFirestore.instance
      .collection('stories')
      .doc()
      .id;
  bool _saving = false;
  Future<void> _publish() async {
    setState(() => _saving = true);
    try {
      ContentModerationService.instance.enforce(_note.text.trim());
      await CreatorService.instance.publishing('story', widget.postId, {
        'requestId': _requestId,
        'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hikâye paylaşılamadı. Gönderi erişimini ve bağlantını kontrol et.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      backgroundColor: const Color(0xFF0B1426),
      appBar: AppBar(title: const Text('Hikâyende paylaş')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Video ve Reels hikâyede oynatılır. İçeriğe dokunanlar asıl gönderiyi açabilir.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            AspectRatio(aspectRatio: 9 / 16, child: SharedPostCard(
              postId: widget.postId, compact: true, storyPresentation: true,
              active: !_saving,
            )),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              maxLength: 180,
              maxLines: 3,
              enabled: !_saving,
              decoration: const InputDecoration(hintText: 'Bir not ekle…'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _publish,
              icon: const Icon(Icons.add_to_photos_outlined),
              label: Text(_saving ? 'Paylaşılıyor…' : 'Hikâyemde paylaş'),
            ),
            const Text(
              'Hikâyen 24 saat görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

