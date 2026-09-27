import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'share_recipient_picker.dart';

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
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: SizedBox(
      height: (MediaQuery.sizeOf(sheetContext).height - MediaQuery.viewInsetsOf(sheetContext).bottom) * .68,
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
          StreamBuilder<List<ChatThread>>(stream: ChatService.instance.myThreads(), builder: (context, snapshot) {
            final groups = (snapshot.data ?? <ChatThread>[]).where((t) => t.isGroup).toList();
            if (groups.isEmpty) return const SizedBox.shrink();
            return SizedBox(height: 110, child: ListView(scrollDirection: Axis.horizontal, children: groups.map((t) => SizedBox(width: 140, child: ListTile(leading: const Icon(Icons.groups), title: Text(t.name, maxLines: 2), onTap: () => Navigator.pop(sheetContext, {'threadId': t.id, 'id': '', 'name': t.name})))).toList()));
          }),
          Expanded(child: ShareRecipientPicker(
            onSelected: (user) => Navigator.pop(sheetContext, user),
          )),
        ],
      ),
    )),
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
    final threadId = target['threadId'] ?? await ChatService.instance.ensureDirectThread(
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

