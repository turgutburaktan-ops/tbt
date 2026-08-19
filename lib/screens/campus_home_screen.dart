import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/activity_demand_service.dart';
import '../services/community_service.dart';
import 'activity_demand_screen.dart';
import 'community_profile_screen.dart';

class CampusHomeScreen extends StatelessWidget {
  const CampusHomeScreen({super.key});

  static const _bg = Color(0xFF090A0C);
  static const _card = Color(0xFF121416);
  static const _border = Color(0xFF292D32);
  static const _accent = Color(0xFFB7BCC2);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, auth) {
        final user = auth.data;
        if (user == null) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: Text('Kampüs alanı için giriş yapmalısın.')),
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, profileSnap) {
            if (!profileSnap.hasData) {
              return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator()));
            }
            final profile = profileSnap.data!.data() ?? const <String, dynamic>{};
            final university = (profile['university'] ?? '').toString().trim();
            final department = (profile['department'] ?? '').toString().trim();
            final classYear = (profile['classYear'] ?? '').toString().trim();
            final newStudent = profile['newStudent2026'] == true;
            final interests = (profile['interests'] as List? ?? const []).map((e) => e.toString()).toList();

            if (university.isEmpty) {
              return Scaffold(
                backgroundColor: _bg,
                appBar: AppBar(backgroundColor: _bg, title: const Text('Kampüs')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.school_outlined, size: 68, color: Colors.white38),
                      const SizedBox(height: 16),
                      const Text('Kampüsünü seç', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('Toplulukları, kampüs etkinliklerini ve sana uygun aktiviteleri gösterebilmemiz için üniversite bilgini ekle.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.4)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/campus-profile'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Kampüs Profilini Oluştur'),
                      ),
                    ]),
                  ),
                ),
              );
            }

            return Scaffold(
              backgroundColor: _bg,
              appBar: AppBar(
                backgroundColor: _bg,
                titleSpacing: 16,
                title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kampüs', style: TextStyle(fontSize: 13, color: Colors.white54)),
                  Text(university, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ]),
                actions: [
                  IconButton(
                    tooltip: 'Kampüs profilini düzenle',
                    onPressed: () => Navigator.pushNamed(context, '/campus-profile'),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 36),
                children: [
                  if (newStudent) _WelcomeCard(university: university, department: department, classYear: classYear),
                  _QuickActions(university: university, interests: interests),
                  const SizedBox(height: 18),
                  _CampusDemandSection(university: university),
                  const SizedBox(height: 22),
                  _CampusCommunitiesSection(university: university),
                  const SizedBox(height: 22),
                  _CampusEventsSection(university: university),
                  const SizedBox(height: 22),
                  _CampusPostsSection(university: university),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String university, department, classYear;
  const _WelcomeCard({required this.university, required this.department, required this.classYear});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: CampusHomeScreen._card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CampusHomeScreen._border),
        ),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF25292E), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.waving_hand_outlined, size: 27)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('2026 • Kampüse hoş geldin', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 4),
            Text([department, classYear.isEmpty ? '' : '$classYear. sınıf'].where((e) => e.isNotEmpty).join(' • '), style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 5),
            const Text('Topluluklarını keşfet, ilk etkinliğine katıl ve kampüsü tanı.', style: TextStyle(color: Colors.white70, height: 1.35)),
          ])),
        ]),
      );
}

class _QuickActions extends StatelessWidget {
  final String university;
  final List<String> interests;
  const _QuickActions({required this.university, required this.interests});

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String title, String subtitle, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Container(
              height: 108,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: CampusHomeScreen._card, borderRadius: BorderRadius.circular(17), border: Border.all(color: CampusHomeScreen._border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: CampusHomeScreen._accent),
                const Spacer(),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white46)),
              ]),
            ),
          ),
        );
    return Row(children: [
      action(Icons.groups_2_outlined, 'Topluluklar', 'Kampüsünü keşfet', () => Navigator.pushNamed(context, '/communities')),
      const SizedBox(width: 9),
      action(Icons.bolt_outlined, 'Ne yapalım?', 'Talep oluştur', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityDemandScreen(initialActivity: interests.isEmpty ? 'Fotoğraf' : interests.first)))),
      const SizedBox(width: 9),
      action(Icons.person_outline, 'Profilim', 'Bölüm ve ilgi alanları', () => Navigator.pushNamed(context, '/campus-profile')),
    ]);
  }
}

class _CampusDemandSection extends StatelessWidget {
  final String university;
  const _CampusDemandSection({required this.university});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityDemand>>(
      stream: ActivityDemandService.instance.watchActive(),
      builder: (context, snapshot) {
        final matches = (snapshot.data ?? const <ActivityDemand>[]).where((d) => d.university.toLowerCase() == university.toLowerCase()).toList();
        final counts = <String, int>{};
        for (final d in matches) {
          counts[d.activity] = (counts[d.activity] ?? 0) + 1;
        }
        final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(title: 'Kampüste ne yapmak istiyorlar?', action: 'Talep oluştur', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityDemandScreen(initialActivity: 'Fotoğraf')))),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            const _EmptyMini(text: 'Kampüsünde henüz aktivite talebi yok. İlk talebi sen oluştur.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sorted.take(6).map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: CampusHomeScreen._card, borderRadius: BorderRadius.circular(14), border: Border.all(color: CampusHomeScreen._border)),
                child: Text('${e.key}  •  ${e.value} kişi', style: const TextStyle(fontWeight: FontWeight.w800)),
              )).toList(),
            ),
        ]);
      },
    );
  }
}

class _CampusCommunitiesSection extends StatelessWidget {
  final String university;
  const _CampusCommunitiesSection({required this.university});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CommunityService.instance.watchCommunities(university: university),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle(title: 'Topluluklar', action: 'Tümünü gör', onTap: () => Navigator.pushNamed(context, '/communities')),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              const _EmptyMini(text: 'Bu üniversitede henüz topluluk eklenmemiş.')
            else
              SizedBox(
                height: 142,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length > 8 ? 8 : docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    return InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityProfileScreen(communityId: docs[i].id))),
                      borderRadius: BorderRadius.circular(17),
                      child: Container(
                        width: 176,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(color: CampusHomeScreen._card, borderRadius: BorderRadius.circular(17), border: Border.all(color: CampusHomeScreen._border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [const CircleAvatar(radius: 20, backgroundColor: Color(0xFF25292E), child: Icon(Icons.groups_2_outlined, size: 21)), const Spacer(), if (d['verified'] == true) const Icon(Icons.verified, size: 18, color: CampusHomeScreen._accent)]),
                          const Spacer(),
                          Text((d['name'] ?? 'Topluluk').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text((d['description'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white46)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
          ]);
        },
      );
}

class _CampusEventsSection extends StatelessWidget {
  final String university;
  const _CampusEventsSection({required this.university});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CommunityService.instance.watchCommunities(university: university),
        builder: (context, communities) {
          final ids = (communities.data?.docs ?? const []).map((d) => d.id).toSet();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('social_events').where('visibility', isEqualTo: 'public').limit(100).snapshots(),
            builder: (context, eventsSnap) {
              final now = DateTime.now();
              final docs = (eventsSnap.data?.docs ?? const []).where((doc) {
                final d = doc.data();
                if (!ids.contains((d['communityId'] ?? '').toString())) return false;
                if ((d['status'] ?? 'open') != 'open') return false;
                final raw = d['startsAt'];
                return raw is Timestamp && raw.toDate().isAfter(now.subtract(const Duration(minutes: 30)));
              }).toList()
                ..sort((a, b) => (a.data()['startsAt'] as Timestamp).compareTo(b.data()['startsAt'] as Timestamp));
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionTitle(title: 'Yaklaşan kampüs etkinlikleri'),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  const _EmptyMini(text: 'Toplulukların yaklaşan herkese açık etkinliği henüz yok.')
                else
                  ...docs.take(5).map((doc) {
                    final d = doc.data();
                    final dt = (d['startsAt'] as Timestamp).toDate().toLocal();
                    final date = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(color: CampusHomeScreen._card, borderRadius: BorderRadius.circular(16), border: Border.all(color: CampusHomeScreen._border)),
                      child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF25292E), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.event_outlined)),
                        const SizedBox(width: 11),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((d['title'] ?? 'Etkinlik').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('${d['communityName'] ?? d['hostName'] ?? ''} • $date', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        ])),
                        Text('${(d['participantIds'] as List? ?? const []).length} kişi', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      ]),
                    );
                  }),
              ]);
            },
          );
        },
      );
}

class _CampusPostsSection extends StatelessWidget {
  final String university;
  const _CampusPostsSection({required this.university});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').where('university', isEqualTo: university).limit(80).snapshots(),
        builder: (context, usersSnap) {
          final campusUsers = (usersSnap.data?.docs ?? const []).map((d) => d.id).toSet();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(80).snapshots(),
            builder: (context, postsSnap) {
              final docs = (postsSnap.data?.docs ?? const []).where((doc) => campusUsers.contains((doc.data()['userId'] ?? '').toString())).take(8).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionTitle(title: 'Kampüsten son paylaşımlar'),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  const _EmptyMini(text: 'Kampüsünden henüz paylaşım görünmüyor.')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      final image = (d['imageUrl'] ?? '').toString();
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: image.isEmpty
                            ? Container(color: CampusHomeScreen._card, child: const Icon(Icons.photo_outlined, color: Colors.white30))
                            : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: CampusHomeScreen._card, child: const Icon(Icons.broken_image_outlined))),
                      );
                    },
                  ),
              ]);
            },
          );
        },
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const _SectionTitle({required this.title, this.action, this.onTap});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ]);
}

class _EmptyMini extends StatelessWidget {
  final String text;
  const _EmptyMini({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: CampusHomeScreen._card, borderRadius: BorderRadius.circular(16), border: Border.all(color: CampusHomeScreen._border)),
        child: Text(text, style: const TextStyle(color: Colors.white54, height: 1.35)),
      );
}
