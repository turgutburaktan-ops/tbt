// Shared engagement controls for posts and social events.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/content_engagement_service.dart';

class ContentEngagementBar extends StatelessWidget {
  final String collection;
  final String contentId;
  final String ownerId;
  final String title;
  final String sourceType;

  const ContentEngagementBar({
    super.key,
    required this.collection,
    required this.contentId,
    required this.ownerId,
    required this.title,
    required this.sourceType,
  });

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _comments(BuildContext context) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF090812),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .68,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Yorumlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ContentEngagementService.instance.comments(collection, contentId),
                  builder: (_, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? const [];
                    if (docs.isEmpty) return const Center(child: Text('Henüz yorum yok. İlk yorumu sen yap.'));
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                      itemBuilder: (_, index) {
                        final data = docs[index].data();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text((data['userName'] ?? 'Kullanıcı').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text((data['text'] ?? '').toString()),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLength: 500,
                      decoration: const InputDecoration(hintText: 'Yorum yaz…', counterText: ''),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () async {
                      try {
                        await ContentEngagementService.instance.addComment(
                          collection: collection,
                          id: contentId,
                          ownerId: ownerId,
                          title: title,
                          text: controller.text,
                          sourceType: sourceType,
                        );
                        controller.clear();
                      } catch (e) {
                        if (sheetContext.mounted) _message(sheetContext, e.toString().replaceFirst('Exception: ', ''));
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<Map<String, String>?> _pickUser(BuildContext context, String heading) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF090812),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(heading, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ContentEngagementService.instance.users(),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final users = snapshot.data!.docs.where((d) => d.id != me).toList();
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final doc = users[index];
                      final data = doc.data();
                      final name = (data['displayName'] ?? data['email'] ?? 'Kullanıcı').toString();
                      final photo = (data['photoUrl'] ?? '').toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                          child: photo.isEmpty ? const Icon(Icons.person_outline) : null,
                        ),
                        title: Text(name),
                        onTap: () => Navigator.pop(sheetContext, {'id': doc.id, 'name': name}),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StreamBuilder<bool>(
          stream: ContentEngagementService.instance.isLiked(collection, contentId),
          builder: (_, likedSnapshot) => StreamBuilder<int>(
            stream: ContentEngagementService.instance.likesCount(collection, contentId),
            builder: (_, countSnapshot) {
              final liked = likedSnapshot.data ?? false;
              final count = countSnapshot.data ?? 0;
              return TextButton.icon(
                onPressed: () async {
                  try {
                    await ContentEngagementService.instance.toggleLike(
                      collection: collection,
                      id: contentId,
                      ownerId: ownerId,
                      title: title,
                      sourceType: sourceType,
                    );
                  } catch (e) {
                    _message(context, e.toString().replaceFirst('Exception: ', ''));
                  }
                },
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.redAccent : null),
                label: Text(count == 0 ? 'Beğen' : '$count'),
              );
            },
          ),
        ),
        IconButton(
          tooltip: 'Yorumlar',
          onPressed: () => _comments(context),
          icon: const Icon(Icons.mode_comment_outlined),
        ),
        IconButton(
          tooltip: 'Etiketle',
          onPressed: () async {
            final user = await _pickUser(context, 'Birini etiketle');
            if (user == null || !context.mounted) return;
            try {
              await ContentEngagementService.instance.tagUser(
                collection: collection,
                id: contentId,
                userId: user['id'] ?? '',
                userName: user['name'] ?? 'Kullanıcı',
                title: title,
                sourceType: sourceType,
              );
              if (context.mounted) _message(context, '${user['name']} etiketlendi.');
            } catch (e) {
              if (context.mounted) _message(context, e.toString().replaceFirst('Exception: ', ''));
            }
          },
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Gönder',
          onPressed: () async {
            final user = await _pickUser(context, 'Kime göndermek istiyorsun?');
            if (user == null || !context.mounted) return;
            try {
              await ContentEngagementService.instance.shareToUser(
                targetUserId: user['id'] ?? '',
                sourceType: sourceType,
                sourceId: contentId,
                title: title,
              );
              if (context.mounted) _message(context, '${user['name']} kullanıcısına gönderildi.');
            } catch (e) {
              if (context.mounted) _message(context, e.toString().replaceFirst('Exception: ', ''));
            }
          },
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    );
  }
}
