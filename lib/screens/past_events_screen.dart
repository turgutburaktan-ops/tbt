import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/social_event.dart';
import '../services/post_service.dart';
import '../services/social_event_service.dart';
import 'event_deep_link_screen.dart';

class PastEventsScreen extends StatelessWidget {
  final bool embedded;
  const PastEventsScreen({super.key, this.embedded = false});

  Widget _body(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Geçmiş etkinliklerin için giriş yapmalısın.'));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(SocialEventService.collection)
          .where('participantIds', arrayContains: uid)
          .limit(120)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('Geçmiş etkinlikler yüklenemedi.\n${snapshot.error}', textAlign: TextAlign.center)));
        final now = DateTime.now();
        final events = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map(SocialEvent.fromDocument)
            .where((event) => !event.startsAt.isAfter(now))
            .toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
        if (events.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.photo_album_outlined, size: 64, color: Colors.white30), SizedBox(height: 12), Text('Henüz geçmiş etkinliğin yok.', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('Katıldığın etkinlikler başladıktan sonra burada anı albümüne dönüşecek.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))])));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (_, index) {
            final event = events[index];
            final d = event.startsAt.toLocal();
            final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: PostService.instance.eventMemories(event.id),
              builder: (_, memories) {
                final memoryCount = memories.data?.docs.length ?? 0;
                return Card(
                  color: const Color(0xFF121416),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: const CircleAvatar(radius: 25, backgroundColor: Color(0xFF25292E), child: Icon(Icons.photo_library_outlined)),
                    title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('$date${event.city.isEmpty ? '' : ' • ${event.city}'}\n${event.participantCount} katılımcı • $memoryCount anı'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: event.id))),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    if (embedded) return ColoredBox(color: const Color(0xFF090A0C), child: body);
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0C), title: const Text('Etkinlik Anılarım')),
      body: body,
    );
  }
}
