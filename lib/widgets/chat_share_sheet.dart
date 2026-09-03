import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../theme/app_theme.dart';

Future<void> shareCardToChat(
  BuildContext context, {
  required String sharedType,
  required String sharedId,
  required String title,
  String? imageUrl,
}) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null) {
    _notice(context, 'Göndermek için giriş yapmalısın.');
    return;
  }

  final target = await showModalBottomSheet<Map<String, String>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .68,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mesaj olarak gönder',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .limit(100)
                  .snapshots(),
              builder: (_, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Kullanıcılar yüklenemedi.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!.docs
                    .where((doc) => doc.id != me.uid)
                    .toList(growable: false);
                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'Gönderebileceğin bir kullanıcı bulunamadı.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (_, index) {
                    final doc = users[index];
                    final data = doc.data();
                    final name =
                        (data['displayName'] ?? data['email'] ?? 'Kullanıcı')
                            .toString();
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceStrong,
                        child: Icon(Icons.person_outline_rounded),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(Icons.send_rounded, size: 19),
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

  if (target == null || !context.mounted) return;
  try {
    final targetId = target['id'] ?? '';
    String? resolvedImageUrl = imageUrl;
    if ((resolvedImageUrl ?? '').trim().isEmpty && sharedType == 'event') {
      try {
        final event = await FirebaseFirestore.instance
            .collection('social_events')
            .doc(sharedId)
            .get();
        final data = event.data();
        resolvedImageUrl = (data?['coverImageUrl'] ?? '').toString().trim();
      } catch (_) {
        // Kapak olmasa da gerçek etkinlik kimliğiyle mesaj gönderilir.
      }
    }
    final threadId = await ChatService.instance.ensureDirectThread(
      targetId,
      sourceType: sharedType,
      sourceId: sharedId,
    );
    await ChatService.instance.sendSharedContent(
      threadId: threadId,
      otherUserId: targetId,
      sharedType: sharedType,
      sharedId: sharedId,
      title: title,
      imageUrl: resolvedImageUrl,
    );
    if (context.mounted) {
      _notice(context, '${target['name']} kullanıcısına gönderildi.');
    }
  } catch (error) {
    if (context.mounted) {
      _notice(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }
}

void _notice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
