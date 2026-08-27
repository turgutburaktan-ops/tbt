import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TbtEngagementCard extends StatelessWidget {
  const TbtEngagementCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final stats = data['stats'] is Map
            ? Map<String, dynamic>.from(data['stats'])
            : const <String, dynamic>{};
        final posts = (stats['posts'] as num?)?.toInt() ?? 0;
        final events = (stats['eventsCreated'] as num?)?.toInt() ?? 0;
        final favorites = data['favoritePlaces'] is Map
            ? (data['favoritePlaces'] as Map).length
            : 0;
        final following = (stats['following'] as num?)?.toInt() ?? 0;
        final score =
            (posts * 20 +
                    events * 50 +
                    favorites * 10 +
                    following.clamp(0, 10) * 5)
                .clamp(0, 999999);
        final level = _level(score);
        final missions = <_Mission>[
          _Mission(
            'İlk paylaşımını yap',
            Icons.add_a_photo_outlined,
            posts > 0,
            20,
          ),
          _Mission(
            'Bir mekanı favorile',
            Icons.favorite_border_rounded,
            favorites > 0,
            10,
          ),
          _Mission(
            'İlk etkinliğini oluştur',
            Icons.groups_2_outlined,
            events > 0,
            50,
          ),
          _Mission(
            '3 kişiyi takip et',
            Icons.person_add_alt_1_rounded,
            following >= 3,
            15,
          ),
        ];
        final done = missions.where((m) => m.done).length;
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 16,
            vertical: 8,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF11141A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF292E38)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8A1FF).withValues(alpha: .13),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(level.icon, color: const Color(0xFFB8A1FF)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$score puan • $done/${missions.length} başlangıç görevi',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Badge(label: level.badge),
                ],
              ),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: done / missions.length,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                ...missions.map(
                  (mission) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Icon(
                          mission.done
                              ? Icons.check_circle_rounded
                              : mission.icon,
                          size: 18,
                          color: mission.done
                              ? const Color(0xFF73E6A2)
                              : Colors.white54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mission.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: mission.done
                                  ? Colors.white54
                                  : Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          '+${mission.points}',
                          style: const TextStyle(
                            color: Color(0xFFB8A1FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Bugün bir şey yap: paylaş, favorile veya çevrende bir etkinlik başlat.',
                  style: TextStyle(color: Colors.white60, fontSize: 11.5),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  _Level _level(int score) {
    if (score >= 1000)
      return const _Level(
        'Şehir Uzmanı',
        'UZMAN',
        Icons.workspace_premium_rounded,
      );
    if (score >= 400)
      return const _Level('Yerel Rehber', 'REHBER', Icons.explore_rounded);
    if (score >= 120)
      return const _Level('Kaşif', 'KAŞİF', Icons.travel_explore_rounded);
    return const _Level('Yeni Gezgin', 'YENİ', Icons.hiking_rounded);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFB8A1FF).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0xFFB8A1FF).withValues(alpha: .35)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFD4C7FF),
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
        letterSpacing: .5,
      ),
    ),
  );
}

class _Mission {
  const _Mission(this.title, this.icon, this.done, this.points);
  final String title;
  final IconData icon;
  final bool done;
  final int points;
}

class _Level {
  const _Level(this.name, this.badge, this.icon);
  final String name;
  final String badge;
  final IconData icon;
}
