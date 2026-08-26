import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/app_notification_service.dart';
import '../services/favorites_service.dart';
import '../widgets/spot_image.dart';
import 'post_detail_screen.dart';
import 'social_events_screen.dart';
import 'spot_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0;

  static const _surface = Color(0xFF121416);
  static const _surfaceAlt = Color(0xFF1A1D20);
  static const _border = Color(0xFF2A2E33);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Text(
              'Kaydedilenler',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              children: [
                _TabChip(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Kaydedilenler',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _TabChip(
                  icon: Icons.favorite_border_rounded,
                  label: 'Beğeniler',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                _TabChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Yorumlar',
                  selected: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                ),
                _TabChip(
                  icon: Icons.alternate_email_rounded,
                  label: 'Sosyal',
                  selected: _tab == 3,
                  onTap: () => setState(() => _tab = 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                _SavedSpotsTab(),
                _ActivityTab(kind: _ActivityKind.likes),
                _ActivityTab(kind: _ActivityKind.comments),
                _ActivityTab(kind: _ActivityKind.social),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? _LibraryScreenState._surfaceAlt : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? Colors.white38 : _LibraryScreenState._border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.white54,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedSpotsTab extends StatelessWidget {
  const _SavedSpotsTab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PhotoSpot>>(
      valueListenable: FavoritesService.savedSpots,
      builder: (context, spots, _) {
        if (spots.isEmpty) {
          return const _EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'Henüz kaydettiğin bir nokta yok',
            subtitle:
                'Beğendiğin çekim noktalarını kaydettiğinde burada göreceksin.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
          itemCount: spots.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final spot = spots[index];
            return Material(
              color: _LibraryScreenState._surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SpotDetailScreen(spot: spot),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _LibraryScreenState._border),
                  ),
                  child: Row(
                    children: [
                      SpotImage(
                        spot: spot,
                        width: 74,
                        height: 74,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spot.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${spot.city} • ${spot.category}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '★ ${spot.rating}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kaydı kaldır',
                        onPressed: () => FavoritesService.toggle(spot),
                        icon: const Icon(
                          Icons.bookmark_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _ActivityKind { likes, comments, social }

class _ActivityTab extends StatelessWidget {
  final _ActivityKind kind;
  const _ActivityTab({required this.kind});

  bool _matches(AppNotificationItem item) {
    final type = item.type.toLowerCase();
    switch (kind) {
      case _ActivityKind.likes:
        return type.contains('like');
      case _ActivityKind.comments:
        return type.contains('comment');
      case _ActivityKind.social:
        return type.contains('tag') ||
            type.contains('follow') ||
            type.contains('event_join') ||
            type.contains('mention');
    }
  }

  String get _emptyTitle => switch (kind) {
    _ActivityKind.likes => 'Henüz beğeni bildirimin yok',
    _ActivityKind.comments => 'Henüz yorum bildirimin yok',
    _ActivityKind.social => 'Henüz sosyal bildirimin yok',
  };

  IconData get _emptyIcon => switch (kind) {
    _ActivityKind.likes => Icons.favorite_border_rounded,
    _ActivityKind.comments => Icons.chat_bubble_outline_rounded,
    _ActivityKind.social => Icons.people_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotificationItem>>(
      stream: AppNotificationService.instance.watchMine(limit: 120),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (snapshot.data ?? const <AppNotificationItem>[])
            .where(_matches)
            .toList(growable: false);
        if (items.isEmpty) {
          return _EmptyState(
            icon: _emptyIcon,
            title: _emptyTitle,
            subtitle: 'Yeni hareketler olduğunda burada görünecek.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white10),
          itemBuilder: (context, index) => _ActivityTile(item: items[index]),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AppNotificationItem item;
  const _ActivityTile({required this.item});

  IconData _iconFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('like')) return Icons.favorite_rounded;
    if (value.contains('comment')) return Icons.chat_bubble_rounded;
    if (value.contains('tag') || value.contains('mention'))
      return Icons.alternate_email_rounded;
    if (value.contains('follow')) return Icons.person_add_alt_1_rounded;
    if (value.contains('event')) return Icons.groups_2_outlined;
    return Icons.notifications_none_rounded;
  }

  String _timeLabel() {
    final time = item.createdAt;
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inHours < 1) return '${diff.inMinutes} dk';
    if (diff.inDays < 1) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} g';
    return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
  }

  Future<void> _open(BuildContext context) async {
    await AppNotificationService.instance.markRead(item.id);
    if (!context.mounted) return;

    final sourceId = item.sourceId?.trim() ?? '';
    if (sourceId.isEmpty) return;

    if (item.type.startsWith('post_')) {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(sourceId)
          .get();
      if (!context.mounted || !doc.exists) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PostDetailScreen(post: {...?doc.data(), 'id': doc.id}),
        ),
      );
      return;
    }

    if (item.type.contains('event')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Etkinlikler')),
            body: const SocialEventsScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: _LibraryScreenState._surfaceAlt,
        child: Icon(_iconFor(item.type), color: Colors.white70, size: 21),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: item.read ? FontWeight.w600 : FontWeight.w900,
          color: item.read ? Colors.white70 : Colors.white,
        ),
      ),
      subtitle: Text(
        item.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, height: 1.3),
      ),
      trailing: Text(
        _timeLabel(),
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      onTap: () => _open(context),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.white24),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
