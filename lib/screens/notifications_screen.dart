import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';
import '../widgets/firebase_media_image.dart';
import 'event_deep_link_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await AppNotificationService.instance.refreshCampusDigest();
      try {
        await AppNotificationService.instance.markAllRead();
      } catch (_) {}
    });
  }

  static const _eventTypes = <String>{
    'event_join',
    'social_event_join',
    'event_cancelled',
    'social_event_cancelled',
    'community_event',
    'event_memory',
    'campus_digest',
  };

  bool _opensEvent(String type) => _eventTypes.contains(type);

  bool _isSocial(String type) =>
      type == 'follow' || type.startsWith('post_') || type.startsWith('story_');

  IconData _iconFor(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add_alt_1_rounded;
      case 'post_like':
      case 'story_like':
        return Icons.favorite_rounded;
      case 'post_comment':
        return Icons.mode_comment_rounded;
      case 'post_tag':
        return Icons.alternate_email_rounded;
      case 'story_reaction':
        return Icons.emoji_emotions_rounded;
      case 'event_join':
      case 'social_event_join':
        return Icons.group_add_rounded;
      case 'event_cancelled':
      case 'social_event_cancelled':
        return Icons.event_busy_rounded;
      case 'community_event':
        return Icons.groups_2_rounded;
      case 'event_memory':
        return Icons.photo_library_rounded;
      case 'campus_digest':
        return Icons.school_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _accentFor(String type) {
    if (type == 'post_like' || type == 'story_like') {
      return const Color(0xFFFF8FA3);
    }
    if (_opensEvent(type)) return const Color(0xFFFFD38A);
    if (_isSocial(type)) return const Color(0xFFB9B2FF);
    return const Color(0xFFB7BCC2);
  }

  Future<Map<String, dynamic>> _actor(String actorId) async {
    if (actorId.trim().isEmpty) return const <String, dynamic>{};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(actorId)
          .get()
          .timeout(const Duration(seconds: 5));
      return doc.data() ?? const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<void> _openItem(AppNotificationItem item) async {
    await AppNotificationService.instance.markRead(item.id);
    if (!mounted) return;

    final sourceId = item.sourceId?.trim() ?? '';
    final actorId = item.actorId?.trim() ?? '';

    if (sourceId.isNotEmpty && _opensEvent(item.type)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDeepLinkScreen(eventId: sourceId),
        ),
      );
      return;
    }

    if (item.type.startsWith('post_') && sourceId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(sourceId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PostDetailScreen(post: {...?doc.data(), 'id': doc.id}),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu paylaşım artık mevcut değil.')),
        );
      }
      return;
    }

    if ((item.type == 'follow' || item.type.startsWith('story_')) &&
        actorId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: actorId)),
      );
    }
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }

  String _groupLabel(DateTime? value) {
    if (value == null) return 'Daha önce';
    final d = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final days = today.difference(date).inDays;
    if (days <= 0) return 'Bugün';
    if (days == 1) return 'Dün';
    return 'Daha önce';
  }

  bool _matchesFilter(AppNotificationItem item) {
    switch (_filter) {
      case 'social':
        return _isSocial(item.type);
      case 'events':
        return _opensEvent(item.type);
      default:
        return true;
    }
  }

  Widget _filterChip(String key, String label, IconData icon) {
    final selected = _filter == key;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? Colors.black : Colors.white60,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: const Color(0xFFD7DADF),
      backgroundColor: const Color(0xFF14171A),
      side: BorderSide(
        color: selected ? const Color(0xFFD7DADF) : const Color(0xFF2A2E33),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _leading(AppNotificationItem item) {
    final actorId = item.actorId?.trim() ?? '';
    if (actorId.isEmpty) return _iconBubble(item.type);
    return FutureBuilder<Map<String, dynamic>>(
      future: _actor(actorId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final photoUrl = (data['photoUrl'] ?? '').toString();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: ClipOval(
                child: FirebaseMediaImage(
                  imageUrl: photoUrl,
                  fallbackStoragePaths: FirebaseMediaImage.avatarPaths(actorId),
                  fit: BoxFit.cover,
                  errorWidget: const ColoredBox(
                    color: Color(0xFF1A1D20),
                    child: Center(
                      child: Icon(Icons.person_rounded, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: _accentFor(item.type),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF101214), width: 2),
                ),
                child: Icon(_iconFor(item.type), size: 12, color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _iconBubble(String type) {
    final accent = _accentFor(type);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Icon(_iconFor(type), color: accent, size: 22),
    );
  }

  Widget _itemCard(AppNotificationItem item) {
    final actionable =
        _opensEvent(item.type) ||
        item.type == 'follow' ||
        item.type.startsWith('post_') ||
        item.type.startsWith('story_');
    return Material(
      color: item.read ? const Color(0xFF111315) : const Color(0xFF181C20),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openItem(item),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.read
                  ? const Color(0xFF24282D)
                  : const Color(0xFF3A4047),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leading(item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title.isEmpty ? 'Bildirim' : item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: item.read
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!item.read) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _accentFor(item.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      _timeLabel(item.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionable)
                const Padding(
                  padding: EdgeInsets.only(left: 5, top: 13),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white30,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Bildirimler',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Bildirim seçenekleri',
            color: const Color(0xFF181A1D),
            onSelected: (value) {
              if (value == 'read_all') {
                AppNotificationService.instance.markAllRead();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Tümünü okundu yap'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<AppNotificationItem>>(
        stream: AppNotificationService.instance.watchMine(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
            );
          }

          final allItems = snapshot.data ?? const <AppNotificationItem>[];
          final items = allItems.where(_matchesFilter).toList(growable: false);
          final unread = allItems.where((e) => !e.read).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                child: Row(
                  children: [
                    Text(
                      unread == 0
                          ? 'Her şey güncel'
                          : '$unread okunmamış bildirim',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 45,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(
                      'all',
                      'Tümü',
                      Icons.notifications_none_rounded,
                    ),
                    const SizedBox(width: 7),
                    _filterChip('social', 'Sosyal', Icons.people_alt_outlined),
                    const SizedBox(width: 7),
                    _filterChip('events', 'Etkinlik', Icons.event_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_none_rounded,
                                size: 58,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allItems.isEmpty
                                    ? 'Henüz bildirimin yok'
                                    : 'Bu bölümde yeni bildirim yok',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Beğeni, yorum, takip ve etkinlik gelişmeleri burada görünür. Mesajlar yalnızca Mesajlar bölümünde tutulur.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final group = _groupLabel(item.createdAt);
                          final previousGroup = index == 0
                              ? null
                              : _groupLabel(items[index - 1].createdAt);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (group != previousGroup)
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    4,
                                    index == 0 ? 5 : 18,
                                    4,
                                    8,
                                  ),
                                  child: Text(
                                    group,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              _itemCard(item),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
