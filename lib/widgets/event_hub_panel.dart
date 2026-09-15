import '../screens/event_chat_screen.dart';
import 'profile_name_link.dart';
import 'tbt_dialog.dart';
import '../screens/user_profile_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/social_event.dart';

/// Shared event programme, visible participants and participant-only conversation.
class EventHubPanel extends StatelessWidget {
  final SocialEvent event;
  final Future<void> Function()? onCancel;
  const EventHubPanel({super.key, required this.event, this.onCancel});
  static const fields = {
    'program': 'Program',
    'meetingPoint': 'Buluşma noktası',
    'included': 'Dahil olanlar',
    'bring': 'Yanında getir',
    'announcement': 'Sabit duyuru',
  };
  DocumentReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance.collection('social_events').doc(event.id);
  Future<void> _edit(BuildContext context, Map<String, dynamic> data) async {
    final controls = {
      for (final k in fields.keys)
        k: TextEditingController(text: '${data[k] ?? ''}'),
    };
    final save = await showTbtDialog<bool>(
      context: context,
      builder: (c) => TbtDialog(
        title: const Text('Etkinlik bilgileri'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final k in fields.keys)
                  TextField(
                    controller: controls[k],
                    maxLines: k == 'program' ? 4 : 2,
                    maxLength: k == 'program'
                        ? 2000
                        : k == 'meetingPoint'
                        ? 500
                        : 1000,
                    decoration: InputDecoration(labelText: fields[k]),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    try {
      if (save == true)
        await ref.collection('info').doc('main').set({
          for (final k in fields.keys) k: controls[k]!.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bilgiler kaydedilemedi. Tekrar dene.')),
        );
    } finally {
      for (final c in controls.values) c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final member =
        uid != null &&
        (event.hostId == uid || event.participantIds.contains(uid));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.collection('info').doc('main').snapshots(),
          builder: (context, s) {
            final data = s.data?.data() ?? <String, dynamic>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final k in fields.keys)
                  if ('${data[k] ?? ''}'.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fields[k]!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('${data[k]}'),
                        ],
                      ),
                    ),
                if (s.hasError) const Text('Etkinlik bilgileri yüklenemedi.'),
              ],
            );
          },
        ),
        if (uid != null)
          ExpansionTile(
            title: Text('Katılımcılar (${event.visibleParticipantCount})'),
            subtitle: const Text('Gizli katılanların isimleri gösterilmez.'),
            children: [_EventPeople(ids: event.participantIds)],
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: member
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EventChatScreen(event: event)),
                )
              : null,
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Etkinlik sohbeti'),
        ),
        if (uid == event.hostId)
          Align(alignment: Alignment.centerRight, child: PopupMenuButton<String>(
            tooltip: 'Etkinliği yönet',
            child: const Padding(padding: EdgeInsets.all(12), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.more_horiz), SizedBox(width: 6), Text('Etkinliği yönet')])),
            itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Program ve duyuruyu düzenle')), if (onCancel != null) const PopupMenuItem(value: 'cancel', child: Text('Etkinliği iptal et'))],
            onSelected: (action) async {
              if (action == 'cancel') { await onCancel?.call(); return; }
              try { final snap = await ref.collection('info').doc('main').get(); if (context.mounted) await _edit(context, snap.data() ?? {}); }
              catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilgiler yüklenemedi. Tekrar dene.'))); }
            },
          )),
        if (!member)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Sohbete girmek için görünür olarak katıl.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}

class _EventPeople extends StatefulWidget {
  final List<String> ids;
  const _EventPeople({required this.ids});
  @override
  State<_EventPeople> createState() => _EventPeopleState();
}

class _EventPeopleState extends State<_EventPeople> {
  int count = 20;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final id in widget.ids.take(count))
        FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
          future: Future.wait([
            FirebaseFirestore.instance.collection('users').doc(id).get(),
            FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('following')
                .doc(id)
                .get(),
          ]),
          builder: (c, s) {
            final d = s.data?.first.data() ?? {};
            return ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: id),
                ),
              ),
              leading: const Icon(Icons.person_outline),
              title: Text(
                '${d['displayName'] ?? d['username'] ?? 'Katılımcı'}',
              ),
              subtitle: s.data?.last.exists == true
                  ? const Text('Takip ediyorsun')
                  : null,
            );
          },
        ),
      if (count < widget.ids.length)
        TextButton(
          onPressed: () => setState(() => count += 20),
          child: const Text('Daha fazla göster'),
        ),
    ],
  );
}

