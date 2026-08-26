import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RewardsHubScreen extends StatelessWidget {
  const RewardsHubScreen({super.key});

  static const _levels = <(int, String)>[
    (0, 'Gezgin'),
    (200, 'Kaşif'),
    (600, 'Fotoğraf Avcısı'),
    (1500, 'Şehir Rehberi'),
    (3000, 'Usta Kaşif'),
    (6000, 'Türkiye Kaşifi'),
  ];

  (int, String, int) _levelInfo(int xp) {
    var index = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (xp >= _levels[i].$1) index = i;
    }
    final next = index + 1 < _levels.length ? _levels[index + 1].$1 : xp;
    return (index + 1, _levels[index].$2, next);
  }

  int _count(Map<String, dynamic> data, String period, String action) {
    final raw = data[period];
    if (raw is! Map) return 0;
    return (raw[action] as num?)?.toInt() ?? 0;
  }

  int _bounded(int value, int max) => value.clamp(0, max).toInt();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Görevleri görmek için giriş yapmalısın.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        title: const Text('Görevler & Ödüller'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final xp = (data['xp'] as num?)?.toInt() ?? 0;
          final dailyXp = (data['dailyXp'] as num?)?.toInt() ?? 0;
          final weeklyXp = (data['weeklyXp'] as num?)?.toInt() ?? 0;
          final info = _levelInfo(xp);
          final currentFloor = _levels[info.$1 - 1].$1;
          final range = (info.$3 - currentFloor).clamp(1, 1000000).toInt();
          final progress = info.$3 == xp && info.$1 == _levels.length
              ? 1.0
              : ((xp - currentFloor) / range).clamp(0.0, 1.0).toDouble();
          final city = (data['city'] ?? '').toString().trim();

          final dailyPost = _count(data, 'dailyActions', 'post');
          final dailyStory = _count(data, 'dailyActions', 'story');
          final dailyJoin = _count(data, 'dailyActions', 'event_join');
          final weeklyPost = _count(data, 'weeklyActions', 'post');
          final weeklyEvent = _count(data, 'weeklyActions', 'event_create');
          final weeklyMemory = _count(data, 'weeklyActions', 'event_memory');

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF14171B),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 25,
                          child: Icon(Icons.workspace_premium_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.$2,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Seviye ${info.$1} • $xp XP',
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress, minHeight: 8),
                    const SizedBox(height: 8),
                    Text(
                      info.$1 == _levels.length
                          ? 'En yüksek seviyedesin.'
                          : 'Sonraki seviye için ${info.$3 - xp} XP kaldı.',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Bugünün Görevleri',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _Mission(
                title: 'Bir paylaşım yap',
                subtitle: '+10 XP',
                done: dailyPost >= 1,
                progress: _bounded(dailyPost, 1),
                target: 1,
              ),
              _Mission(
                title: 'Bir Story paylaş',
                subtitle: '+5 XP',
                done: dailyStory >= 1,
                progress: _bounded(dailyStory, 1),
                target: 1,
              ),
              _Mission(
                title: 'Bir etkinliğe katıl',
                subtitle: '+15 XP',
                done: dailyJoin >= 1,
                progress: _bounded(dailyJoin, 1),
                target: 1,
              ),
              const SizedBox(height: 8),
              Text(
                'Bugün kazanılan: $dailyXp XP',
                style: const TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Haftalık Hedefler',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _Mission(
                title: '3 paylaşım yap',
                subtitle: 'Akışı canlı tut',
                done: weeklyPost >= 3,
                progress: _bounded(weeklyPost, 3),
                target: 3,
              ),
              _Mission(
                title: 'Bir etkinlik oluştur',
                subtitle: '+50 XP',
                done: weeklyEvent >= 1,
                progress: _bounded(weeklyEvent, 1),
                target: 1,
              ),
              _Mission(
                title: '2 etkinlik anısı ekle',
                subtitle: 'Topluluğa katkı sağla',
                done: weeklyMemory >= 2,
                progress: _bounded(weeklyMemory, 2),
                target: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'Bu hafta kazanılan: $weeklyXp XP',
                style: const TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                city.isEmpty ? 'Türkiye Sıralaması' : '$city Sıralaması',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _Leaderboard(city: city),
              const SizedBox(height: 22),
              const Text(
                'XP Kazanma',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const _XpRow('Gönderi paylaş', 10),
              const _XpRow('Story paylaş', 5),
              const _XpRow('Etkinlik oluştur', 50),
              const _XpRow('Etkinliğe katıl', 15),
              const _XpRow('Etkinlik anısı ekle', 20),
              const _XpRow('Paylaşımın 50 beğeni alsın', 25),
            ],
          );
        },
      ),
    );
  }
}

class _Mission extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final int progress;
  final int target;

  const _Mission({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.progress,
    required this.target,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF121416),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: done ? Colors.greenAccent : Colors.white38,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          '$progress/$target',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _Leaderboard extends StatelessWidget {
  final String city;

  const _Leaderboard({required this.city});

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .limit(100)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final users = snapshot.data!.docs.where((doc) {
        if (city.isEmpty) return true;
        return (doc.data()['city'] ?? '').toString().trim().toLowerCase() ==
            city.toLowerCase();
      }).toList();
      users.sort(
        (a, b) => ((b.data()['xp'] as num?)?.toInt() ?? 0).compareTo(
          (a.data()['xp'] as num?)?.toInt() ?? 0,
        ),
      );
      final top = users.take(10).toList();
      if (top.isEmpty) {
        return const Text(
          'Sıralama henüz oluşmadı.',
          style: TextStyle(color: Colors.white54),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: List.generate(top.length, (index) {
            final data = top[index].data();
            final name = (data['displayName'] ?? data['username'] ?? 'Kaşif')
                .toString();
            final xp = (data['xp'] as num?)?.toInt() ?? 0;
            return ListTile(
              dense: true,
              leading: CircleAvatar(radius: 16, child: Text('${index + 1}')),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                '$xp XP',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            );
          }),
        ),
      );
    },
  );
}

class _XpRow extends StatelessWidget {
  final String label;
  final int xp;

  const _XpRow(this.label, this.xp);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Text('+$xp XP', style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
