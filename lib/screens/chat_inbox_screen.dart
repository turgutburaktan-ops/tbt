import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/app_notification_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  void _startChat({
    required String userId,
    required String displayName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: userId,
          otherDisplayName: displayName,
        ),
      ),
    );
  }

  Widget _searchResults(String myId) {
    final q = _normalize(_query);
    if (q.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Kullanıcı adı veya isimden aramak için en az 2 harf yaz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.4),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(120).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Kullanıcı araması şu anda kullanılamıyor.'),
          );
        }

        final docs = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((doc) {
          if (doc.id == myId) return false;
          final data = doc.data();
          final displayName = _normalize((data['displayName'] ?? '').toString());
          final username = _normalize((data['username'] ?? data['handle'] ?? '').toString());
          final email = _normalize((data['email'] ?? '').toString());
          return displayName.contains(q) || username.contains(q) || email.contains(q);
        }).toList(growable: false);

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Bu aramayla eşleşen kullanıcı bulunamadı.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: Colors.white10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final displayName = (data['displayName'] ?? data['username'] ?? data['email'] ?? 'Kullanıcı').toString().trim();
            final username = (data['username'] ?? data['handle'] ?? '').toString().trim().replaceFirst(RegExp(r'^@'), '');
            final photoUrl = (data['photoUrl'] ?? '').toString().trim();
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF1A1D20),
                backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
                child: photoUrl.isEmpty ? const Icon(Icons.person_outline, color: Colors.white54) : null,
              ),
              title: Text(
                displayName.isEmpty ? 'Kullanıcı' : displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: username.isEmpty
                  ? const Text('Mesaj gönder', style: TextStyle(color: Colors.white54))
                  : Text('@$username', style: const TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54),
              onTap: () => _startChat(
                userId: doc.id,
                displayName: displayName.isEmpty ? 'Kullanıcı' : displayName,
              ),
            );
          },
        );
      },
    );
  }

  Widget _threads(String myId) {
    return StreamBuilder<List<ChatThread>>(
      stream: ChatService.instance.myThreads(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
          );
        }

        final threads = snapshot.data ?? const <ChatThread>[];
        if (threads.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Colors.white24),
                  const SizedBox(height: 14),
                  const Text(
                    'Henüz mesajın yok.',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yukarıdan bir kullanıcı ara ve doğrudan mesaj gönder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _searchFocus.requestFocus(),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Kullanıcı Ara'),
                  ),
                ],
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
            final otherIds = thread.memberIds.where((id) => id != myId).toList();
            if (otherIds.isEmpty) return const SizedBox.shrink();
            return _ThreadTile(thread: thread, otherUserId: otherIds.first);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: const Text('Mesajlar'),
        actions: [
          IconButton(
            tooltip: 'Yeni mesaj',
            onPressed: () => _searchFocus.requestFocus(),
            icon: const Icon(Icons.edit_square),
          ),
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı ara…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Temizle',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                _searchFocus.unfocus();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: _query.trim().isEmpty ? _threads(myId) : _searchResults(myId),
                ),
              ],
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
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = (data['displayName'] ?? data['username'] ?? 'Topluluk üyesi').toString();
        final username = (data['username'] ?? data['handle'] ?? '').toString().replaceFirst(RegExp(r'^@'), '');
        final photoUrl = (data['photoUrl'] ?? '').toString();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF1A1D20),
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            thread.lastMessage.isEmpty
                ? (username.isEmpty ? 'Sohbeti aç' : '@$username')
                : thread.lastMessage,
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
