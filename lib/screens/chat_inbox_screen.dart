import '../widgets/chat_surface.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/app_notification_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'message_privacy_settings_screen.dart';
import '../widgets/chat_collaboration_controls.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  bool _showRequests = false;
  int _threadsRevision = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  void _startChat({required String userId, required String displayName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(otherUserId: userId, otherDisplayName: displayName),
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
      stream: FirebaseFirestore.instance
          .collection('users')
          .limit(120)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
          );
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Kullanıcı araması şu anda kullanılamıyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ),
          );
        }

        final docs =
            (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) {
                  if (doc.id == myId) return false;
                  final data = doc.data();
                  final displayName = _normalize(
                    (data['displayName'] ?? '').toString(),
                  );
                  final username = _normalize(
                    (data['username'] ?? data['handle'] ?? '').toString(),
                  );
                  final email = _normalize((data['email'] ?? '').toString());
                  return displayName.contains(q) ||
                      username.contains(q) ||
                      email.contains(q);
                })
                .toList(growable: false);

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
          separatorBuilder: (_, __) =>
              const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final displayName =
                (data['displayName'] ??
                        data['username'] ??
                        data['email'] ??
                        'Kullanıcı')
                    .toString()
                    .trim();
            final username = (data['username'] ?? data['handle'] ?? '')
                .toString()
                .trim()
                .replaceFirst(RegExp(r'^@'), '');
            final photoUrl = (data['photoUrl'] ?? '').toString().trim();
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF50383E),
                backgroundImage: photoUrl.isEmpty
                    ? null
                    : NetworkImage(photoUrl),
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person_outline, color: Colors.white54)
                    : null,
              ),
              title: Text(
                displayName.isEmpty ? 'Kullanıcı' : displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: username.isEmpty
                  ? const Text(
                      'Mesaj gönder',
                      style: TextStyle(color: Colors.white54),
                    )
                  : Text(
                      '@$username',
                      style: const TextStyle(color: Colors.white54),
                    ),
              trailing: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white54,
              ),
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
    final revision = _threadsRevision;
    return StreamBuilder<List<ChatThread>>(
      key: ValueKey('threads-$revision'),
      stream: ChatService.instance.myThreads(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
          );
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Colors.white30,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mesajlar şu anda yüklenemedi.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _threadsRevision++),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          );
        }

        final threads = (snapshot.data ?? const <ChatThread>[]).where((t) {
          final incoming = t.requestRecipientId == myId;
          if (incoming && t.requestStatus == 'rejected') return false;
          final request = incoming && t.requestStatus == 'pending';
          return _showRequests ? request && t.lastMessageAt != null : !request;
        }).toList();
        if (threads.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 54,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _showRequests ? 'Bekleyen mesaj isteğin yok.' : 'Henüz mesajın yok.',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _showRequests ? 'Takip etmediğin kişilerden gelen yeni mesajlar burada görünür.' : 'Yukarıdan bir kullanıcı ara ve doğrudan mesaj gönder.',
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          itemCount: threads.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final thread = threads[index];
            final otherIds = thread.memberIds
                .where((id) => id != myId)
                .toList(growable: false);
            if (thread.isGroup) return ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              tileColor: const Color(0xA6241E23),
              leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
              title: Text(thread.name), subtitle: Text(thread.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: '', groupThreadId: thread.id))),
            );
            if (otherIds.isEmpty) return const SizedBox.shrink();
            final lastRead = thread.lastReadAt[myId];
            final unread = thread.lastSenderId != myId &&
                thread.lastMessageAt != null &&
                (lastRead == null || thread.lastMessageAt!.isAfter(lastRead));
            return _ThreadTile(
              thread: thread,
              otherUserId: otherIds.first,
              unread: unread,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return ChatSurface(child: Builder(builder: (context) => Scaffold(
      backgroundColor: const Color(0xFF191519),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191519),
        foregroundColor: Colors.white,
        title: const Text('Mesajlar'),
        titleSpacing: 0,
        actions: [
          IconButton(constraints: const BoxConstraints.tightFor(width: 40), padding: EdgeInsets.zero, tooltip: 'Mesaj ayarları', icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagePrivacySettingsScreen()))),
          PopupMenuButton<String>(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 160), tooltip: 'Grup sohbeti', icon: const Icon(Icons.group_add_outlined), onSelected: (v) => startGroupChat(context, join: v == 'join'), itemBuilder: (_) => const [PopupMenuItem(value: 'create', child: Text('Yeni grup')), PopupMenuItem(value: 'join', child: Text('Davetle katıl'))]),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 40),
            padding: EdgeInsets.zero,
            tooltip: 'Yeni mesaj',
            onPressed: () => _searchFocus.requestFocus(),
            icon: const Icon(Icons.edit_square),
          ),
          StreamBuilder<int>(
            stream: AppNotificationService.instance.unreadCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                constraints: const BoxConstraints.tightFor(width: 40),
                padding: EdgeInsets.zero,
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
      body: ChatBackdrop(child: myId == null
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
                if (_query.trim().isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
                  ChoiceChip(label: const Text('Sohbetler'), selected: !_showRequests, onSelected: (_) => setState(() => _showRequests = false)),
                  const SizedBox(width: 8),
                  StreamBuilder<List<ChatThread>>(stream: ChatService.instance.myThreads(), builder: (context, snap) {
                    final count = (snap.data ?? <ChatThread>[]).where((t) => t.requestRecipientId == myId && t.requestStatus == 'pending' && t.lastMessageAt != null).length;
                    return ChoiceChip(label: Text('İstekler${count > 0 ? ' ($count)' : ''}'), selected: _showRequests, onSelected: (_) => setState(() => _showRequests = true));
                  }),
                ])),
                Expanded(
                  child: _query.trim().isEmpty
                      ? _threads(myId)
                      : _searchResults(myId),
                ),
              ],
            )),
    )));
  }
}

String _threadTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final now = DateTime.now();
  if (now.year == local.year &&
      now.month == local.month &&
      now.day == local.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (now.difference(local).inDays < 7) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[local.weekday - 1];
  }
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
}

class _ThreadTile extends StatelessWidget {
  final ChatThread thread;
  final String otherUserId;
  final bool unread;

  const _ThreadTile({
    required this.thread,
    required this.otherUserId,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ThreadUserPreview>(
      future: _ThreadUserCache.load(otherUserId),
      builder: (context, snapshot) {
        final preview = snapshot.data ?? _ThreadUserPreview.fallback;
        final name = preview.name;
        final username = preview.username;
        final photoUrl = preview.photoUrl;

        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          tileColor: unread ? const Color(0xFF3B2B31) : const Color(0xA6241E23),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF50383E),
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white54)
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              if (thread.lastMessageAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  _threadTime(thread.lastMessageAt),
                  style: TextStyle(
                    color: unread ? const Color(0xFFF3B29B) : Colors.white38,
                    fontSize: 11,
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            thread.lastMessage.isEmpty
                ? (username.isEmpty ? 'Sohbeti aç' : '@$username')
                : thread.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unread ? Colors.white : Colors.white54,
              fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          trailing: unread
              ? const Badge(
                  backgroundColor: Color(0xFFF3B29B),
                  smallSize: 9,
                  child: Icon(Icons.chevron_right, color: Colors.white54),
                )
              : const Icon(Icons.chevron_right, color: Colors.white38),
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

class _ThreadUserPreview {
  final String name;
  final String username;
  final String photoUrl;

  const _ThreadUserPreview({
    required this.name,
    required this.username,
    required this.photoUrl,
  });

  static const fallback = _ThreadUserPreview(
    name: 'Topluluk üyesi',
    username: '',
    photoUrl: '',
  );
}

class _ThreadUserCache {
  static const Duration _lifetime = Duration(minutes: 5);
  static final Map<String, _CachedThreadUser> _cache = {};
  static final Map<String, Future<_ThreadUserPreview>> _inFlight = {};

  static Future<_ThreadUserPreview> load(String userId) {
    final cached = _cache[userId];
    if (cached != null && !cached.isExpired) {
      return Future.value(cached.value);
    }
    final running = _inFlight[userId];
    if (running != null) return running;

    final request = _fetch(userId);
    _inFlight[userId] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[userId], request)) _inFlight.remove(userId);
    });
  }

  static Future<_ThreadUserPreview> _fetch(String userId) async {
    final stale = _cache[userId]?.value;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 4));
      final data = doc.data() ?? const <String, dynamic>{};
      final name =
          (data['displayName'] ?? data['username'] ?? 'Topluluk üyesi')
              .toString()
              .trim();
      final username = (data['username'] ?? data['handle'] ?? '')
          .toString()
          .trim()
          .replaceFirst(RegExp(r'^@'), '');
      final value = _ThreadUserPreview(
        name: name.isEmpty ? 'Topluluk üyesi' : name,
        username: username,
        photoUrl: (data['photoUrl'] ?? '').toString().trim(),
      );
      _cache[userId] = _CachedThreadUser(value, DateTime.now());
      return value;
    } catch (_) {
      return stale ?? _ThreadUserPreview.fallback;
    }
  }
}

class _CachedThreadUser {
  final _ThreadUserPreview value;
  final DateTime savedAt;

  const _CachedThreadUser(this.value, this.savedAt);

  bool get isExpired =>
      DateTime.now().difference(savedAt) > _ThreadUserCache._lifetime;
}

