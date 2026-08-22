import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/activity_demand_service.dart';
import '../services/community_service.dart';
import 'activity_demand_screen.dart';
import 'community_profile_screen.dart';

class CampusHomeScreen extends StatelessWidget {
  const CampusHomeScreen({super.key});

  static const bg = Color(0xFF090A0C);
  static const card = Color(0xFF121416);
  static const border = Color(0xFF292D32);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: Text('Kampüs alanı için giriş yapmalısın.')),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!.data() ?? <String, dynamic>{};
        final university = (data['university'] ?? '').toString().trim();
        final department = (data['department'] ?? '').toString().trim();
        final classYear = (data['classYear'] ?? '').toString().trim();
        final interests = (data['interests'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        final newStudent = data['newStudent2026'] == true;
        const activeStudentYears = <String>{
          'Hazırlık',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
        };
        final campusEligible = university.isNotEmpty &&
            activeStudentYears.contains(classYear);

        if (!campusEligible) {
          return Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              title: const Text('Kampüs'),
              backgroundColor: bg,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      university.isEmpty
                          ? Icons.school_outlined
                          : Icons.lock_outline_rounded,
                      size: 60,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      university.isEmpty
                          ? 'Kampüs profilini oluştur'
                          : 'Kampüs aktif öğrencilere özel',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      university.isEmpty
                          ? 'Kampüs yalnız Hazırlık ile 6. sınıf arasındaki üniversite öğrencilerine açıktır.'
                          : 'Mezun hesaplarda ve aktif öğrenci olmayan hesaplarda Kampüs kapalı kalır.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                    if (university.isEmpty) ...[
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/campus-profile',
                        ),
                        child: const Text('Kampüs Profilini Oluştur'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kampüs',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                Text(
                  university,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/campus-profile',
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
            children: [
              if (newStudent)
                _WelcomeCard(
                  department: department,
                  classYear: classYear,
                ),
              _QuickActions(interests: interests),
              const SizedBox(height: 22),
              _DemandSection(university: university),
              const SizedBox(height: 22),
              _CommunitiesSection(university: university),
              const SizedBox(height: 22),
              _EventsSection(university: university),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String department;
  final String classYear;
  const _WelcomeCard({required this.department, required this.classYear});

  String get _classLabel =>
      classYear == 'Hazırlık' ? 'Hazırlık' : '$classYear. sınıf';

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CampusHomeScreen.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CampusHomeScreen.border),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFF25292E),
              child: Icon(Icons.school_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2026 • Kampüse hoş geldin',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [department, _classLabel]
                        .where((e) => e.isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Topluluklarını keşfet ve ilk etkinliğine katıl.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _QuickActions extends StatelessWidget {
  final List<String> interests;
  const _QuickActions({required this.interests});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, VoidCallback tap) => Expanded(
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 82,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: CampusHomeScreen.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CampusHomeScreen.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 21),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        item(
          Icons.groups_2_outlined,
          'Topluluklar',
          () => Navigator.pushNamed(context, '/communities'),
        ),
        const SizedBox(width: 8),
        item(
          Icons.bolt_outlined,
          'Ne yapalım?',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityDemandScreen(
                initialActivity: interests.isEmpty ? 'Fotoğraf' : interests.first,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        item(
          Icons.person_outline,
          'Profilim',
          () => Navigator.pushNamed(context, '/campus-profile'),
        ),
      ],
    );
  }
}

class _DemandSection extends StatelessWidget {
  final String university;
  const _DemandSection({required this.university});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ActivityDemand>>(
        stream: ActivityDemandService.instance.watchActive(),
        builder: (context, snap) {
          final counts = <String, int>{};
          for (final d in snap.data ?? const <ActivityDemand>[]) {
            if (d.university.toLowerCase() == university.toLowerCase()) {
              counts[d.activity] = (counts[d.activity] ?? 0) + 1;
            }
          }
          final items = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title('Kampüste ne yapmak istiyorlar?'),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const _Empty('Henüz talep yok. İlk talebi sen oluştur.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items
                      .take(6)
                      .map(
                        (e) => ActionChip(
                          label: Text('${e.key} • ${e.value} kişi'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActivityDemandScreen(
                                initialActivity: e.key,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          );
        },
      );
}

class _CommunitiesSection extends StatelessWidget {
  final String university;
  const _CommunitiesSection({required this.university});

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CommunityService.instance.watchCommunities(
          university: university,
        ),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _Title('Topluluklar')),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/communities',
                    ),
                    child: const Text('Tümünü gör'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const _Empty('Bu üniversitede henüz topluluk yok.')
              else
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: docs.length > 8 ? 8 : docs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityProfileScreen(
                              communityId: docs[i].id,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 170,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CampusHomeScreen.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: CampusHomeScreen.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.groups_2_outlined),
                                  const Spacer(),
                                  if (d['verified'] == true)
                                    const Icon(Icons.verified, size: 17),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                (d['name'] ?? 'Topluluk').toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      );
}

class _EventsSection extends StatelessWidget {
  final String university;
  const _EventsSection({required this.university});

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CommunityService.instance.watchCommunities(
          university: university,
        ),
        builder: (context, communitySnap) {
          final ids = (communitySnap.data?.docs ?? const [])
              .map((e) => e.id)
              .toSet();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('social_events')
                .limit(100)
                .snapshots(),
            builder: (context, eventSnap) {
              final now = DateTime.now();
              final events = (eventSnap.data?.docs ?? const []).where((doc) {
                final d = doc.data();
                final raw = d['startsAt'];
                return ids.contains((d['communityId'] ?? '').toString()) &&
                    (d['visibility'] ?? 'public') == 'public' &&
                    (d['status'] ?? 'open') == 'open' &&
                    raw is Timestamp &&
                    raw.toDate().isAfter(now);
              }).toList();
              events.sort(
                (a, b) => (a.data()['startsAt'] as Timestamp)
                    .compareTo(b.data()['startsAt'] as Timestamp),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Title('Yaklaşan kampüs etkinlikleri'),
                  const SizedBox(height: 10),
                  if (events.isEmpty)
                    const _Empty('Yaklaşan kampüs etkinliği henüz yok.')
                  else
                    ...events.take(5).map((doc) {
                      final d = doc.data();
                      final dt =
                          (d['startsAt'] as Timestamp).toDate().toLocal();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CampusHomeScreen.card,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: CampusHomeScreen.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (d['title'] ?? 'Etkinlik').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${d['communityName'] ?? ''} • ${dt.day}.${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(d['participantIds'] as List? ?? const []).length} kişi',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      );
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CampusHomeScreen.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CampusHomeScreen.border),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white60),
        ),
      );
}
