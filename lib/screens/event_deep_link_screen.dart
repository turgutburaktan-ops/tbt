import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/social_event.dart';
import '../services/invite_link_service.dart';
import '../services/post_service.dart';
import '../services/social_event_service.dart';
import 'event_memories_screen.dart';
import 'invite_qr_screen.dart';

class EventDeepLinkScreen extends StatelessWidget {
  final String eventId;
  const EventDeepLinkScreen({super.key, required this.eventId});

  String _dateLabel(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0C), title: const Text('Etkinlik')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(SocialEventService.collection).doc(eventId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('Bu etkinlik özel olabilir veya artık erişilebilir değil.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60))));
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists) return const Center(child: Text('Etkinlik bulunamadı.'));

          final raw = doc.data() ?? const <String, dynamic>{};
          final coverImageUrl = (raw['coverImageUrl'] ?? '').toString().trim();
          final event = SocialEvent.fromDocument(doc);
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final joined = uid != null && event.participantIds.contains(uid);
          final isHost = uid != null && event.hostId == uid;
          final started = !event.startsAt.isAfter(DateTime.now());

          Future<void> toggle() async {
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Katılmak için giriş yapmalısın.')));
              return;
            }
            try {
              if (joined || isHost) {
                await SocialEventService.instance.leave(event.id);
              } else {
                await SocialEventService.instance.join(event.id);
              }
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: const Color(0xFF121416), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF292D32))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (coverImageUrl.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF181B1F),
                          child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 42)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const CircleAvatar(radius: 26, backgroundColor: Color(0xFF25292E), child: Icon(Icons.event_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(event.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Text(event.hostName, style: const TextStyle(color: Colors.white60)),
                        ])),
                        IconButton(
                          tooltip: 'QR',
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InviteQrScreen(title: event.title, subtitle: event.city.isEmpty ? 'Etkinlik daveti' : '${event.city} • Etkinlik daveti', uri: InviteLinkService.instance.eventUri(event.id)))),
                          icon: const Icon(Icons.qr_code_2_rounded),
                        ),
                        IconButton(
                          tooltip: 'Paylaş',
                          onPressed: () => InviteLinkService.instance.shareEvent(eventId: event.id, eventTitle: event.title, hostName: event.hostName, city: event.city),
                          icon: const Icon(Icons.ios_share_outlined),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      _Info(icon: Icons.schedule, text: _dateLabel(event.startsAt)),
                      if (event.city.isNotEmpty) ...[const SizedBox(height: 9), _Info(icon: Icons.location_city_outlined, text: event.city)],
                      if (event.locationLabel.isNotEmpty) ...[const SizedBox(height: 9), _Info(icon: Icons.place_outlined, text: event.locationLabel)],
                      const SizedBox(height: 9),
                      _Info(icon: Icons.groups_2_outlined, text: '${event.participantCount}/${event.capacity} katılımcı'),
                      if (event.description.trim().isNotEmpty) ...[const SizedBox(height: 18), Text(event.description, style: const TextStyle(color: Colors.white70, height: 1.45))],
                      const SizedBox(height: 22),
                      if (started) ...[
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: PostService.instance.eventMemories(event.id),
                          builder: (_, memorySnap) {
                            final count = memorySnap.data?.docs.length ?? 0;
                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventMemoriesScreen(event: event))),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(count == 0 ? 'Etkinlik Anıları' : 'Etkinlik Anıları • $count fotoğraf'),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (!started)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: event.isFull && !joined && !isHost ? null : toggle,
                            child: Text(isHost ? 'Etkinliği İptal Et' : joined ? 'Etkinlikten Ayrıl' : event.isFull ? 'Dolu' : event.isPaid ? 'Bilet Al' : 'Katıl'),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF191C1F), borderRadius: BorderRadius.circular(14)),
                          child: const Row(children: [Icon(Icons.auto_awesome_outlined, size: 18, color: Colors.white60), SizedBox(width: 8), Expanded(child: Text('Etkinlik başladı. Fotoğraflar artık Etkinlik Anıları bölümünde birikebilir.', style: TextStyle(color: Colors.white70)))]),
                        ),
                    ]),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: Colors.white54), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: Colors.white70)))]);
}
