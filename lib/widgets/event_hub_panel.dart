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
  const EventHubPanel({super.key, required this.event});
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
                if (uid == event.hostId)
                  OutlinedButton.icon(
                    onPressed: () => _edit(context, data),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Program ve duyuruyu düzenle'),
                  ),
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
                  MaterialPageRoute(builder: (_) => _EventChat(event: event)),
                )
              : null,
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Etkinlik sohbeti'),
        ),
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

class _EventChat extends StatefulWidget {
  final SocialEvent event;
  const _EventChat({required this.event});
  @override
  State<_EventChat> createState() => _EventChatState();
}

class _EventChatState extends State<_EventChat> {
  final input = TextEditingController();
  bool busy = false;
  CollectionReference<Map<String, dynamic>> get messages => FirebaseFirestore
      .instance
      .collection('social_events')
      .doc(widget.event.id)
      .collection('chat');
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final u = FirebaseAuth.instance.currentUser, text = input.text.trim();
    if (u == null || text.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      await messages.add({
        'senderId': u.uid,
        'senderName': (u.displayName ?? 'Katılımcı').substring(
          0,
          (u.displayName ?? 'Katılımcı').length.clamp(0, 100),
        ),
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      input.clear();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mesaj gönderilemedi. Katılımını ve bağlantını kontrol et.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.event.title)),
    body: SafeArea(
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: messages.parent!.collection('info').doc('main').snapshots(),
            builder: (c, s) {
              final text = '${s.data?.data()?['announcement'] ?? ''}';
              return text.isEmpty
                  ? const SizedBox.shrink()
                  : ListTile(
                      leading: const Icon(Icons.push_pin_outlined),
                      title: Text(text),
                    );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (c, s) {
                if (s.hasError)
                  return const Center(
                    child: Text(
                      'Sohbet yalnızca etkinlik katılımcılarına açık.',
                    ),
                  );
                if (!s.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = s.data!.docs;
                if (docs.isEmpty)
                  return const Center(child: Text('İlk mesajı sen yaz.'));
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final d = docs[i].data();
                    return ListTile(
                      title: ProfileNameLink(userId: (d['senderId'] ?? '').toString(), compact: true, child: Text(
                        '${d['senderName'] ?? 'Katılımcı'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      )),
                      subtitle: Text(
                        '${d['text'] ?? ''}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    maxLength: 1500,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Mesajın'),
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
