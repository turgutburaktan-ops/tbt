import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../screens/share_post_story_screen.dart';
import '../services/creator_service.dart';

class PostSharingActions extends StatefulWidget {
  const PostSharingActions({super.key, required this.postId});
  final String postId;
  @override
  State<PostSharingActions> createState() => _PostSharingActionsState();
}

class _PostSharingActionsState extends State<PostSharingActions> {
  bool _busy = false;
  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = await CreatorService.instance.publishing(
        'state',
        widget.postId,
      );
      if (!mounted) return;
      final action = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (c) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_to_photos_outlined),
              title: const Text('Hikâyende paylaş'),
              onTap: () => Navigator.pop(c, 'story'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: Text(
                state['reposted'] == true
                    ? 'Yeniden paylaşımı geri al'
                    : 'Yeniden paylaş',
              ),
              onTap: () => Navigator.pop(c, 'repost'),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border_rounded),
              title: Text(
                state['saved'] == true ? 'Kaydedilenlerden çıkar' : 'Kaydet',
              ),
              onTap: () => Navigator.pop(c, 'save'),
            ),
          ],
        ),
      );
      if (action == null || !mounted) return;
      if (action == 'story') {
        final shared = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SharePostStoryScreen(postId: widget.postId),
          ),
        );
        if (shared == true && mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hikâyende paylaşıldı.')),
          );
      } else {
        await CreatorService.instance.publishing(action, widget.postId, {
          'enabled': state[action == 'repost' ? 'reposted' : 'saved'] != true,
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'repost'
                    ? (state['reposted'] == true
                          ? 'Yeniden paylaşım geri alındı.'
                          : 'Profilinde ve akışta yeniden paylaşıldı.')
                    : (state['saved'] == true
                          ? 'Kaydedilenlerden çıkarıldı.'
                          : 'Gönderi kaydedildi.'),
              ),
            ),
          );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'İşlem tamamlanamadı.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'İşlem tamamlanamadı. Girişini ve gönderi erişimini kontrol et.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Hikâyede paylaş, yeniden paylaş veya kaydet',
    visualDensity: VisualDensity.compact,
    onPressed: _busy ? null : _open,
    icon: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.repeat_rounded, size: 25),
  );
}
