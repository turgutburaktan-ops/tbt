import 'package:flutter/material.dart';

import '../services/app_notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'social_event_join':
        return Icons.person_add_alt_1_rounded;
      case 'social_event_cancelled':
        return Icons.event_busy_rounded;
      default:
        return Icons.notifications_none_rounded;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        foregroundColor: Colors.white,
        title: const Text('Bildirimler'),
        actions: [
          TextButton(
            onPressed: AppNotificationService.instance.markAllRead,
            child: const Text('Tümünü oku'),
          ),
          const SizedBox(width: 6),
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

          final items = snapshot.data ?? const <AppNotificationItem>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 58, color: Colors.white30),
                    SizedBox(height: 12),
                    Text('Henüz bildirimin yok',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      'Yeni mesajlar ve etkinlik hareketleri burada görünecek.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final item = items[index];
              return Material(
                color: item.read
                    ? const Color(0xFF121416)
                    : const Color(0xFF1C222B),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      AppNotificationService.instance.markRead(item.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0x228B5CF6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconFor(item.type),
                              color: const Color(0xFFB7BCC2), size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title.isEmpty
                                          ? 'Bildirim'
                                          : item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  if (!item.read) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFB7BCC2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (item.body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white60, height: 1.35),
                                ),
                              ],
                              if (item.createdAt != null) ...[
                                const SizedBox(height: 7),
                                Text(_timeLabel(item.createdAt),
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                              ],
                            ],
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
      ),
    );
  }
}
