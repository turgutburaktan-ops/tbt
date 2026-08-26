// Shared engagement controls for posts and social events.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/content_engagement_service.dart';
import '../services/invite_link_service.dart';
import 'mention_text.dart';

class ContentEngagementBar extends StatelessWidget {
  final String collection;
  final String contentId;
  final String ownerId;
  final String title;
  final String sourceType;
  final bool showTagAction;

  const ContentEngagementBar({
    super.key,
    required this.collection,
    required this.contentId,
    required this.ownerId,
    required this.title,
    required this.sourceType,
    this.showTagAction = false,
  });

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _comments(BuildContext context) async {
    if (contentId.trim().isEmpty) {
      _message(context, 'Bu paylaşımın kimliği bulunamadı.');
      return;
    }

    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0E1012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          var sending = false;

          Future<void> sendComment() async {
            final text = controller.text.trim();
            if (text.isEmpty || sending) return;
            setSheetState(() => sending = true);
            try {
              await ContentEngagementService.instance.addComment(
                collection: collection,
                id: contentId,
                ownerId: ownerId,
                title: title,
                text: text,
                sourceType: sourceType,
              );
              controller.clear();
              if (sheetContext.mounted) {
                FocusScope.of(sheetContext).unfocus();
              }
            } catch (e) {
              if (sheetContext.mounted) {
                _message(
                  sheetContext,
                  e.toString().replaceFirst('Exception: ', ''),
                );
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => sending = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .70,
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Yorumlar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ContentEngagementService.instance.comments(
                        collection,
                        contentId,
                      ),
                      builder: (_, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Yorumlar yüklenemedi.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snapshot.data?.docs ?? const [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'Henüz yorum yok. İlk yorumu sen yap.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white10),
                          itemBuilder: (_, index) {
                            final data = docs[index].data();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF1A1D20),
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(
                                (data['userName'] ?? 'Kullanıcı').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: MentionText(
                                text: (data['text'] ?? '').toString(),
                                style: const TextStyle(color: Colors.white70),
                                mentionStyle: const TextStyle(
                                  color: Color(0xFFD7DADF),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15181B),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0x334B5158)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLength: 500,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => sendComment(),
                            decoration: const InputDecoration(
                              hintText: 'Yorum yaz…',
                              counterText: '',
                              border: InputBorder.none,
                              filled: false,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFB7BCC2),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: sending ? null : sendComment,
                          icon: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<Map<String, String>?> _pickUser(
    BuildContext context,
    String heading,
  ) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0E1012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      heading,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ContentEngagementService.instance.users(),
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Kullanıcılar yüklenemedi.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snapshot.data!.docs
                      .where((d) => d.id != me)
                      .toList();
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final doc = users[index];
                      final data = doc.data();
                      final name =
                          (data['displayName'] ?? data['email'] ?? 'Kullanıcı')
                              .toString();
                      final photo = (data['photoUrl'] ?? '').toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photo.isEmpty
                              ? null
                              : NetworkImage(photo),
                          child: photo.isEmpty
                              ? const Icon(Icons.person_outline)
                              : null,
                        ),
                        title: Text(name),
                        onTap: () => Navigator.pop(sheetContext, {
                          'id': doc.id,
                          'name': name,
                        }),
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

  Future<void> _shareOutside(BuildContext context) async {
    if (contentId.trim().isEmpty) return;
    try {
      if (sourceType == 'post') {
        await InviteLinkService.instance.sharePost(
          postId: contentId,
          title: title,
        );
      } else if (sourceType == 'event') {
        await InviteLinkService.instance.shareEvent(
          eventId: contentId,
          eventTitle: title,
        );
      } else {
        _message(context, 'Bu içerik dışarıya paylaşılamıyor.');
      }
    } catch (_) {
      if (context.mounted) _message(context, 'Paylaşım menüsü açılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB7BCC2);
    const likedColor = Color(0xFFFF5D7A);
    return Row(
      children: [
        StreamBuilder<bool>(
          stream: ContentEngagementService.instance.isLiked(
            collection,
            contentId,
          ),
          builder: (_, likedSnapshot) => StreamBuilder<int>(
            stream: ContentEngagementService.instance.likesCount(
              collection,
              contentId,
            ),
            builder: (_, countSnapshot) {
              final liked = likedSnapshot.data ?? false;
              final count = countSnapshot.data ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: liked ? 'Beğeniyi kaldır' : 'Beğen',
                    visualDensity: VisualDensity.compact,
                    onPressed: contentId.trim().isEmpty
                        ? null
                        : () async {
                            try {
                              await ContentEngagementService.instance
                                  .toggleLike(
                                    collection: collection,
                                    id: contentId,
                                    ownerId: ownerId,
                                    title: title,
                                    sourceType: sourceType,
                                  );
                            } catch (e) {
                              if (context.mounted) {
                                _message(
                                  context,
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            }
                          },
                    icon: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: liked ? likedColor : Colors.white,
                      size: 27,
                    ),
                  ),
                  if (count > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        IconButton(
          tooltip: 'Yorumlar',
          visualDensity: VisualDensity.compact,
          onPressed: contentId.trim().isEmpty ? null : () => _comments(context),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 25),
        ),
        if (showTagAction)
          IconButton(
            tooltip: 'Etiketle',
            visualDensity: VisualDensity.compact,
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
                if (context.mounted)
                  _message(context, '${user['name']} etiketlendi.');
              } catch (e) {
                if (context.mounted)
                  _message(
                    context,
                    e.toString().replaceFirst('Exception: ', ''),
                  );
              }
            },
            icon: const Icon(
              Icons.alternate_email_rounded,
              size: 25,
              color: accent,
            ),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'WhatsApp veya başka uygulamada paylaş',
          visualDensity: VisualDensity.compact,
          onPressed: contentId.trim().isEmpty
              ? null
              : () => _shareOutside(context),
          icon: const Icon(Icons.ios_share_rounded, size: 25),
        ),
        IconButton(
          tooltip: 'TBT içinde gönder',
          visualDensity: VisualDensity.compact,
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
              if (context.mounted)
                _message(context, '${user['name']} kullanıcısına gönderildi.');
            } catch (e) {
              if (context.mounted)
                _message(context, e.toString().replaceFirst('Exception: ', ''));
            }
          },
          icon: const Icon(Icons.send_outlined, size: 26),
        ),
      ],
    );
  }
}
