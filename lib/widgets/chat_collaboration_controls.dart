import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../screens/chat_screen.dart';
import '../screens/create_group_screen.dart';
import '../screens/event_create_screen_v2.dart';

Future<String?> chatTextPrompt(BuildContext context, String title, {String initial = '', int maxLength = 1500}) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
    title: Text(title),
    content: TextField(controller: controller, autofocus: true, maxLength: maxLength, minLines: 1, maxLines: 5),
    actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(dialog, controller.text.trim()), child: const Text('Tamam'))],
  ));
  // The dialog may still be animating out; its controller is owned by the field
  // until route disposal, so dispose after the transition has completed.
  Future.delayed(const Duration(seconds: 1), controller.dispose);
  return value == null || value.isEmpty ? null : value;
}

Future<void> runChatAction(BuildContext context, String action, Map<String, dynamic> data) async {
  try { await ChatService.instance.action(action, data); }
  catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
}

Future<void> startGroupChat(BuildContext context, {bool join = false, String initialCode = ''}) async {
  if (!join) {
    final threadId = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
    if (threadId != null && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: '', groupThreadId: threadId)));
    return;
  }
  final value = await chatTextPrompt(context, join ? 'Davet kodunu gir ve katıl' : 'Grup adı', initial: initialCode, maxLength: join ? 128 : 80);
  if (value == null || !context.mounted) return;
  try {
    final result = await ChatService.instance.action(join ? 'join' : 'create', join ? {'code': value.startsWith('tbt://group/') ? Uri.parse(value).pathSegments.last : value} : {'name': value});
    if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: '', groupThreadId: result['threadId'] as String)));
  } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
}

class ChatPreferencesButton extends StatelessWidget {
  const ChatPreferencesButton({super.key, required this.threadId});
  final String threadId;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('users/$uid/chat_preferences/$threadId').snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        return PopupMenuButton<String>(
          tooltip: 'Sohbet tercihleri', icon: Icon(data['muted'] == true ? Icons.notifications_off_outlined : Icons.tune),
          onSelected: (v) => runChatAction(context, 'preferences', {'threadId': threadId, 'muted': v == 'mute' ? data['muted'] != true : data['muted'] == true, 'readReceipts': v == 'read' ? data['readReceipts'] == false : data['readReceipts'] != false}),
          itemBuilder: (_) => [PopupMenuItem(value: 'mute', child: Text(data['muted'] == true ? 'Bildirimleri aç' : 'Sessize al')), PopupMenuItem(value: 'read', child: Text(data['readReceipts'] == false ? 'Okundu bilgisini aç' : 'Okundu bilgisini kapat'))],
        );
      },
    );
  }
}

class ChatGroupInfo extends StatelessWidget {
  const ChatGroupInfo({super.key, required this.threadId});
  final String threadId;
  Future<void> _act(BuildContext context, String action, [Map<String, dynamic> extra = const {}]) => runChatAction(context, action, {'threadId': threadId, ...extra});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Grup bilgisi')),
    body: StreamBuilder<ChatThread?>(stream: ChatService.instance.watchThread(threadId), builder: (context, snapshot) {
      final t = snapshot.data, uid = FirebaseAuth.instance.currentUser!.uid;
      if (snapshot.hasError) return const Center(child: Text('Bu gruba erişimin yok.'));
      if (t == null) return const Center(child: CircularProgressIndicator());
      final admin = t.adminIds.contains(uid), owner = t.ownerId == uid;
      return ListView(children: [
        ListTile(leading: CircleAvatar(backgroundImage: t.photoUrl == null ? null : NetworkImage(t.photoUrl!), child: t.photoUrl == null ? const Icon(Icons.groups) : null), title: Text(t.name), subtitle: Text('${t.memberIds.length}/50 üye')),
        if (admin) ...[
          ListTile(leading: const Icon(Icons.edit), title: const Text('Grup adını düzenle'), onTap: () async { final name = await chatTextPrompt(context, 'Grup adı', initial: t.name, maxLength: 80); if (name != null && context.mounted) await _act(context, 'rename', {'name': name}); }),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Grup fotoğrafı'), onTap: () async {
            try { final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 640, imageQuality: 85); if (image == null) return;
              final ref = FirebaseStorage.instance.ref('users/$uid/chat_groups/$threadId.jpg');
              await ref.putData(await image.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
              final url = await ref.getDownloadURL(); if (context.mounted) await _act(context, 'photo', {'photoUrl': url});
            } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
          }),
          ListTile(leading: const Icon(Icons.person_add_alt), title: const Text('Davet bağlantısı oluştur ve kopyala'), subtitle: const Text('7 gün geçerli. Önceki kod iptal edilir.'), onTap: () async {
            try { final r = await ChatService.instance.action('invite', {'threadId': threadId}); await Clipboard.setData(ClipboardData(text: 'tbt://group/${r['code']}')); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Davet bağlantısı kopyalandı. Arkadaşın Mesajlar → Davetle katıl alanına girebilir.'))); }
            catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
          }),
        ],
        const Divider(),
        for (final member in t.memberIds) FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(future: FirebaseFirestore.instance.doc('users/$member').get(), builder: (context, user) {
          final name = (user.data?.data()?['displayName'] ?? 'Üye').toString();
          return ListTile(title: Text(name), subtitle: Text(member == t.ownerId ? 'Grup sahibi' : t.adminIds.contains(member) ? 'Yönetici' : 'Üye'), trailing: member == uid ? null : PopupMenuButton<String>(onSelected: (action) async {
            if (action == 'block') { await ChatService.instance.blockUser(member); }
            else if (action == 'report') { await ChatService.instance.reportUser(otherUserId: member, reason: 'group_chat_report', threadId: threadId); }
            else { await _act(context, action, {'userId': member}); }
          }, itemBuilder: (_) => [
            if (admin && member != t.ownerId) const PopupMenuItem(value: 'remove', child: Text('Gruptan çıkar')),
            if (owner) const PopupMenuItem(value: 'admin', child: Text('Yönetici yap')),
            if (owner) const PopupMenuItem(value: 'transfer', child: Text('Sahipliği devret')),
            const PopupMenuItem(value: 'block', child: Text('Kullanıcıyı engelle')),
            const PopupMenuItem(value: 'report', child: Text('Kullanıcıyı bildir')),
          ]));
        }),
        ListTile(leading: const Icon(Icons.logout), title: const Text('Gruptan ayrıl'), subtitle: owner ? const Text('Önce sahipliği başka bir üyeye devret.') : null, onTap: owner && t.memberIds.length > 1 ? null : () async {
          try { await ChatService.instance.action('leave', {'threadId': threadId}); if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst); }
          catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
        }),
      ]);
    }),
  );
}

Future<void> createChatPoll(BuildContext context, String threadId) async {
  final question = await chatTextPrompt(context, 'Anket sorusu', maxLength: 200);
  if (question == null || !context.mounted) return;
  final options = await chatTextPrompt(context, 'Her satıra bir seçenek yaz (2–6)', maxLength: 726);
  if (options == null || !context.mounted) return;
  await runChatAction(context, 'poll', {'threadId': threadId, 'question': question, 'options': options.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()});
}

class ChatPollCard extends StatelessWidget {
  const ChatPollCard({super.key, required this.threadId, required this.message});
  final String threadId;
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(message.text, style: const TextStyle(fontWeight: FontWeight.bold)),
      for (var i = 0; i < message.options.length; i++) OutlinedButton(
        onPressed: message.closed ? null : () => runChatAction(context, 'vote', {'threadId': threadId, 'messageId': message.id, 'option': i}),
        child: Text('${message.votes[uid] == i ? '✓ ' : ''}${message.options[i]} · ${message.votes.values.where((v) => v == i).length} oy'),
      ),
      Text(message.closed ? 'Anket kapandı' : '${message.votes.length} kişi oy verdi · Oyunu değiştirebilirsin', style: const TextStyle(fontSize: 11)),
      TextButton(onPressed: () => createGroupPlan(context, threadId, poll: message), child: const Text('Bu anketten etkinlik planla')),
      if (!message.closed && message.senderId == uid) TextButton(onPressed: () => runChatAction(context, 'closePoll', {'threadId': threadId, 'messageId': message.id}), child: const Text('Anketi kapat')),
    ]);
  }
}

Future<void> createGroupPlan(BuildContext context, String threadId, {ChatMessage? poll}) async {
  final thread = await ChatService.instance.watchThread(threadId).first;
  if (thread == null || !context.mounted) return;
  final description = poll == null ? '' : '${poll.text}\n${List.generate(poll.options.length, (i) => '${poll.options[i]}: ${poll.votes.values.where((v) => v == i).length} oy').join('\n')}';
  final eventId = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => EventCreateScreenV2(initialTitle: poll?.text ?? '${thread.name} buluşması', initialDescription: description, initialCapacity: thread.memberIds.length < 2 ? 2 : thread.memberIds.length, initialGroupMembers: thread.memberIds, returnEventId: true)));
  if (eventId == null) return;
  try { await ChatService.instance.sendSharedContent(threadId: threadId, otherUserId: '', sharedType: 'event', sharedId: eventId, title: poll?.text ?? '${thread.name} buluşması'); }
  catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik oluşturuldu. Sohbete paylaşım başarısız; etkinlikten yeniden paylaşabilirsin.'))); }
}
