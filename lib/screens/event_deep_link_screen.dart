import '../theme/map_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/tbt_dialog.dart';
import '../utils/event_presentation.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_name_link.dart';
import '../widgets/event_hub_panel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_post_screen.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Etkinlik'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(SocialEventService.collection)
            .doc(eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Bu etkinlik özel olabilir veya artık erişilebilir değil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            );
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists)
            return const Center(child: Text('Etkinlik bulunamadı.'));

          final raw = doc.data() ?? const <String, dynamic>{};
          final coverImageUrl = (raw['coverImageUrl'] ?? '').toString().trim();
          final event = SocialEvent.fromDocument(doc);
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final joined = uid != null && event.participantIds.contains(uid);
          final isHost = uid != null && event.hostId == uid;
          final started = !event.startsAt.isAfter(DateTime.now());

          Future<void> toggle() async {
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Katılmak için giriş yapmalısın.'),
                ),
              );
              return;
            }
            if (isHost) {
              final confirmed = await showTbtDialog<bool>(context: context, builder: (c) => TbtDialog(
                title: const Text('Etkinlik iptal edilsin mi?'),
                content: const Text('Katılımcılara etkinliğin iptal edildiği bildirilecek.'),
                actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('İptal et'))],
              ));
              if (confirmed != true || !context.mounted) return;
            }
            try {
              if (joined || isHost) {
                await SocialEventService.instance.leave(event.id);
              } else {
                await SocialEventService.instance.join(event.id);
              }
            } catch (e) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                  ),
                );
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (coverImageUrl.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          coverImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF181B1F),
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                                size: 42,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    ProfileNameLink(userId: event.hostId, compact: true, child: Text(
                                      event.hostName,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                      ),
                                    )),
                                  ],
                                ),
                              ),

                            ],
                          ),
                          Wrap(spacing: 4, children: [
                              IconButton(
                                tooltip: 'QR',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InviteQrScreen(
                                      title: event.title,
                                      subtitle: event.city.isEmpty
                                          ? 'Etkinlik daveti'
                                          : '${event.city} • Etkinlik daveti',
                                      uri: InviteLinkService.instance.eventUri(
                                        event.id,
                                      ),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.qr_code_2_rounded),
                              ),
                              IconButton(
                                tooltip: 'Paylaş',
                                onPressed: () =>
                                    InviteLinkService.instance.shareEvent(
                                      eventId: event.id,
                                      eventTitle: event.title,
                                      hostName: event.hostName,
                                      city: event.city,
                                    ),
                                icon: const Icon(Icons.ios_share_outlined),
                              ),                          ]),
                          const SizedBox(height: 18),
                          _Info(
                            icon: Icons.schedule,
                            text: eventStartLabel(event.startsAt),
                          ),
                          if (event.city.isNotEmpty && !event.locationLabel.toLowerCase().contains(event.city.toLowerCase())) ...[
                            const SizedBox(height: 9),
                            _Info(
                              icon: Icons.location_city_outlined,
                              text: event.city,
                            ),
                          ],
                          if (event.locationLabel.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            _Info(
                              icon: Icons.place_outlined,
                              text: event.locationLabel,
                            ),
                          ],
                          const SizedBox(height: 9),
                          _Info(
                            icon: Icons.groups_2_outlined,
                            text:
                                '${event.participantCount}/${event.capacity} katılımcı',
                          ),
                          if (event.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text(
                              event.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.45,
                              ),
                            ),
                          ],
                          if (event.hasCoordinates && !event.approximateLocationOnly) ...[
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.map_outlined), label: const Text('Buluşma noktası'),
                                onPressed: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SizedBox(
                                  height: 340, child: GoogleMap(
            style: tbtDarkMapStyle,
                                    initialCameraPosition: CameraPosition(target: LatLng(event.latitude!, event.longitude!), zoom: 16),
                                    markers: {Marker(markerId: const MarkerId('meeting'), position: LatLng(event.latitude!, event.longitude!), infoWindow: InfoWindow(title: event.title, snippet: event.locationLabel))},
                                  ),
                                )),
                              ),
                              OutlinedButton.icon(icon: const Icon(Icons.directions_outlined), label: const Text('Yol tarifi'), onPressed: () async {
                                final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '${event.latitude},${event.longitude}'});
                                try { if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception(); }
                                catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harita açılamadı. Tekrar dene.'))); }
                              }),
                            ]),
                          ],
                          EventHubPanel(event: event, onCancel: isHost && !started && event.status == 'open' ? toggle : null),
                          const SizedBox(height: 22),
                          if (started) ...[
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: PostService.instance.eventMemories(
                                event.id,
                              ),
                              builder: (_, memorySnap) {
                                final count = memorySnap.data?.docs.length ?? 0;
                                return SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EventMemoriesScreen(event: event),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                    label: Text(
                                      count == 0
                                          ? 'Etkinlik Anıları'
                                          : 'Etkinlik Anıları • $count fotoğraf',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (!started && !isHost && event.status == 'open')
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                onPressed: event.isFull && !joined && !isHost
                                    ? null
                                    : toggle,
                                child: Text(
                                  isHost
                                      ? 'Etkinliği İptal Et'
                                      : joined
                                      ? 'Etkinlikten Ayrıl'
                                      : event.isFull
                                      ? 'Dolu'
                                      : event.isPaid
                                      ? 'Bilet Al'
                                      : 'Katıl',
                                ),
                              ),
                            )
                          else if (started || event.status == 'cancelled')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF191C1F),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 18,
                                    color: Colors.white60,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      event.status == 'cancelled' ? 'Bu etkinlik iptal edildi.' : 'Etkinlik başladı. Fotoğraflar artık Etkinlik Anıları bölümünde birikebilir.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Colors.white54),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    ],
  );
}

