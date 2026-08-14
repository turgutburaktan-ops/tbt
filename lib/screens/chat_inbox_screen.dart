import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/app_notification_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatelessWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF090D10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D10),
        foregroundColor: Colors.white,
        title: const Text('Mesajlar'),
        actions: [
          StreamBuilder<int>(
            stream: AppNotificationService.instance.unreadCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Bildirimler',
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: myId == null
          ? const Center(
              child: Text(
                'Mesajlarını görmek için giriş yapmalısın.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : StreamBuilder<List<ChatThread>>(
              stream: ChatService.instance.myThreads(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF16B8A6)),
                  );
                }

                final threads = snapshot.data ?? const <ChatThread>[];
                if (threads.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'Henüz mesajın yok. Bir kullanıcı profilinden veya bir etkinlikten sohbet başlatabilirsin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.45),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: threads.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 74,
                    color: Colors.white10,
                  ),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final otherIds =
                        thread.memberIds.where((id) => id != myId).toList();
                    if (otherIds.isEmpty) return const SizedBox.shrink();
                    return _ThreadTile(
                        thread: thread, otherUserId: otherIds.first);
                  },
                );
              },
            ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThread thread;
  final String otherUserId;

  const _ThreadTile({
    required this.thread,
    required this.otherUserId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['displayName'] ?? 'Topluluk üyesi').toString();
        final photoUrl = (data['photoUrl'] ?? '').toString();

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF152128),
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white54)
                : null,
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            thread.lastMessage.isEmpty ? 'Sohbeti aç' : thread.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherUserId: otherUserId,
                  otherDisplayName: name,
                  sourceType: thread.sourceType,
                  sourceId: thread.sourceId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
