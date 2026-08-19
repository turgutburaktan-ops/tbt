import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/social_event.dart';
import '../services/community_service.dart';
import '../services/invite_link_service.dart';
import '../services/social_event_service.dart';
import 'event_deep_link_screen.dart';
import 'event_location_picker_screen.dart';

class CommunityProfileScreen extends StatelessWidget {
  final String communityId;
  const CommunityProfileScreen({super.key, required this.communityId});

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createEvent(BuildContext context, Map<String, dynamic> community) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final admins = (community['adminIds'] as List? ?? const []).map((e) => e.toString()).toList();
    if (uid == null || !admins.contains(uid)) {
      _message(context, 'Bu topluluk adına etkinlik oluşturma yetkin yok.');
      return;
    }

    final title = TextEditingController();
    final city = TextEditingController();
    final location = TextEditingController();
    final description = TextEditingController();
    final capacity = TextEditingController(text: '30');
    SocialEventType type = SocialEventType.social;
    DateTime startsAt = DateTime.now().add(const Duration(hours: 2));
    EventLocationSelection? selectedLocation;
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF090A0C),
      builder: (sheet) => StatefulBuilder(builder: (context, setState) {
        Future<void> pickDateTime() async {
          final date = await showDatePicker(
            context: context,
            initialDate: startsAt,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (date == null || !context.mounted) return;
          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
          if (time == null) return;
          setState(() => startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
        }

        Future<void> pickLocation() async {
          final result = await Navigator.push<EventLocationSelection>(
            context,
            MaterialPageRoute(
              builder: (_) => EventLocationPickerScreen(
                city: city.text,
                addressLabel: location.text,
                initialLatitude: selectedLocation?.latitude,
                initialLongitude: selectedLocation?.longitude,
              ),
            ),
          );
          if (result == null || !context.mounted) return;
          setState(() {
            selectedLocation = result;
            if (location.text.trim().isEmpty) location.text = result.label;
            error = null;
          });
        }

        final local = startsAt.toLocal();
        final dateLabel = '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

        return Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${(community['name'] ?? 'Topluluk')} adına etkinlik', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Etkinlik başlığı')),
              const SizedBox(height: 12),
              DropdownButtonFormField<SocialEventType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Tür'),
                items: SocialEventType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                onChanged: (v) { if (v != null) setState(() => type = v); },
              ),
              const SizedBox(height: 12),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'Şehir')),
              const SizedBox(height: 12),
              TextField(controller: location, decoration: const InputDecoration(labelText: 'Buluşma adresi / mekân')),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: pickLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(selectedLocation == null ? 'Haritadan konum seç' : 'Konum seçildi • Değiştir'),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('Tarih ve saat'),
                subtitle: Text(dateLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: pickDateTime,
              ),
              TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Katılımcı kapasitesi')),
              const SizedBox(height: 12),
              TextField(controller: description, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Açıklama')),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: saving ? null : () async {
                    final cap = int.tryParse(capacity.text.trim()) ?? 0;
                    if (cap < 1) { setState(() => error = 'Katılımcı kapasitesi en az 1 olmalı.'); return; }
                    if (selectedLocation == null) { setState(() => error = 'Haritadan kesin konumu seç.'); return; }
                    setState(() { saving = true; error = null; });
                    try {
                      await SocialEventService.instance.create(
                        title: title.text,
                        type: type,
                        startsAt: startsAt,
                        capacity: cap,
                        city: city.text,
                        locationLabel: location.text,
                        description: description.text,
                        latitude: selectedLocation!.latitude,
                        longitude: selectedLocation!.longitude,
                        communityId: communityId,
                        communityName: (community['name'] ?? '').toString(),
                      );
                      if (sheet.mounted) Navigator.pop(sheet);
                      if (context.mounted) _message(context, 'Topluluk etkinliği oluşturuldu.');
                    } catch (e) {
                      if (sheet.mounted) setState(() { saving = false; error = e.toString().replaceFirst('Exception: ', ''); });
                    }
                  },
                  icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                  label: Text(saving ? 'Oluşturuluyor…' : 'Etkinliği Oluştur'),
                ),
              ),
            ]),
          ),
        );
      }),
    );

    title.dispose(); city.dispose(); location.dispose(); description.dispose(); capacity.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(backgroundColor: const Color(0xFF090A0C), title: const Text('Topluluk')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('communities').doc(communityId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text('Topluluk bulunamadı.'));
          final d = snapshot.data!.data() ?? const <String, dynamic>{};
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final admins = (d['adminIds'] as List? ?? const []).map((e) => e.toString()).toList();
          final isAdmin = uid != null && admins.contains(uid);
          final verified = d['verified'] == true;
          final name = (d['name'] ?? 'Topluluk').toString();
          final university = (d['university'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CircleAvatar(radius: 38, backgroundColor: Color(0xFF24282D), child: Icon(Icons.groups_2_outlined, size: 34)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                    if (verified) const Icon(Icons.verified, color: Color(0xFFB7BCC2)),
                  ]),
                  const SizedBox(height: 4),
                  Text(university, style: const TextStyle(color: Colors.white60)),
                  if ((d['description'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(d['description'].toString(), style: const TextStyle(color: Colors.white70, height: 1.35)),
                  ],
                ])),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                StreamBuilder<int>(
                  stream: CommunityService.instance.followerCount(communityId),
                  builder: (_, s) => Expanded(child: _Stat(value: '${s.data ?? 0}', label: 'Takipçi')),
                ),
                const SizedBox(width: 8),
                Expanded(child: _Stat(value: '${admins.length}', label: 'Yönetici')),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: StreamBuilder<bool>(
                    stream: CommunityService.instance.isFollowing(communityId),
                    builder: (_, s) => FilledButton.tonal(
                      onPressed: () async {
                        try { await CommunityService.instance.toggleFollow(communityId); }
                        catch (e) { if (context.mounted) _message(context, e.toString().replaceFirst('Exception: ', '')); }
                      },
                      child: Text(s.data == true ? 'Takiptesin' : 'Takip Et'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Topluluğu paylaş',
                  onPressed: () => InviteLinkService.instance.shareCommunity(
                    communityId: communityId,
                    communityName: name,
                    university: university,
                  ),
                  icon: const Icon(Icons.ios_share_outlined),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton.icon(onPressed: () => _createEvent(context, d), icon: const Icon(Icons.add), label: const Text('Etkinlik'))),
                ],
              ]),
              const SizedBox(height: 24),
              const Text('Etkinlikler', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              StreamBuilder<List<SocialEvent>>(
                stream: SocialEventService.instance.watchForCommunity(communityId),
                builder: (context, eventsSnapshot) {
                  final events = eventsSnapshot.data ?? const <SocialEvent>[];
                  if (!eventsSnapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                  if (events.isEmpty) return const _EmptyEvents();
                  return Column(children: events.map((event) => _EventCard(event: event)).toList());
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFF121416), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF272B30))),
    child: Column(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))]),
  );
}

class _EventCard extends StatelessWidget {
  final SocialEvent event;
  const _EventCard({required this.event});
  @override
  Widget build(BuildContext context) {
    final d = event.startsAt.toLocal();
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Card(
      color: const Color(0xFF121416),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: event.id)),
        ),
        leading: const CircleAvatar(backgroundColor: Color(0xFF25292E), child: Icon(Icons.event_outlined)),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('$date${event.city.isEmpty ? '' : ' • ${event.city}'}\n${event.participantCount}/${event.capacity} katılımcı'),
        isThreeLine: true,
        trailing: event.status == 'cancelled'
            ? const Text('İptal', style: TextStyle(color: Colors.redAccent))
            : IconButton(
                tooltip: 'Paylaş',
                onPressed: () => InviteLinkService.instance.shareEvent(
                  eventId: event.id,
                  eventTitle: event.title,
                  hostName: event.hostName,
                  city: event.city,
                ),
                icon: const Icon(Icons.ios_share_outlined),
              ),
      ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: const Color(0xFF121416), borderRadius: BorderRadius.circular(16)),
    child: const Column(children: [Icon(Icons.event_available_outlined, color: Colors.white38, size: 34), SizedBox(height: 8), Text('Henüz topluluk etkinliği yok.', style: TextStyle(color: Colors.white60))]),
  );
}
