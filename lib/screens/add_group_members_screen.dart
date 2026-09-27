import '../widgets/profile_name_link.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/share_recipient_picker.dart';

class AddGroupMembersScreen extends StatefulWidget {
  const AddGroupMembersScreen({super.key, required this.threadId});
  final String threadId;
  @override
  State<AddGroupMembersScreen> createState() => _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState extends State<AddGroupMembersScreen> {
  final _selected = <String, String>{};
  bool _saving = false;
  late final _thread = ChatService.instance.watchThread(widget.threadId);

  Future<void> _save(List<String> currentMembers) async {
    final ids = _selected.keys.where((id) => !currentMembers.contains(id)).toList();
    if (_saving || ids.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ChatService.instance.action('addMembers', {'threadId': widget.threadId, 'memberIds': ids});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçtiğin kişiler gruba eklendi.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ChatThread?>(
    stream: _thread,
    builder: (context, snapshot) {
      final thread = snapshot.data;
      final allowed = thread?.adminIds.contains(FirebaseAuth.instance.currentUser?.uid) == true;
      final members = thread?.memberIds ?? <String>[];
      final selected = _selected.keys.where((id) => !members.contains(id)).toSet();
      return PopScope(canPop: !_saving, child: Scaffold(
        appBar: AppBar(title: const Text('Gruba kişi ekle'), actions: [TextButton(
          onPressed: !allowed || _saving || selected.isEmpty || members.length + selected.length > 50 ? null : () => _save(members),
          child: Text(_saving ? 'Ekleniyor…' : 'Ekle (${selected.length})'),
        )]),
        body: snapshot.hasError ? const Center(child: Text('Grup yüklenemedi.'))
          : !snapshot.hasData ? const Center(child: CircularProgressIndicator())
          : !allowed ? const Center(child: Text('Kişi eklemek için yönetici olmalısın.'))
          : AbsorbPointer(absorbing: _saving, child: Column(children: [
            Padding(padding: const EdgeInsets.all(12), child: Text('${members.length}/50 üye · ${selected.length} kişi seçildi')),
            if (selected.isNotEmpty) SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, children: selected.map((id) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InputChip(label: ProfileNameLink(userId: id, compact: true, child: Text(_selected[id]!)), onDeleted: () => setState(() => _selected.remove(id))),
            )).toList())),
            Expanded(child: ShareRecipientPicker(excludedIds: members.toSet(), selectedIds: selected, onSelected: (user) {
              final id = user['id']!;
              if (!_selected.containsKey(id) && members.length + selected.length >= 50) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grup en fazla 50 kişi olabilir.')));
                return;
              }
              setState(() { if (_selected.containsKey(id)) { _selected.remove(id); } else { _selected[id] = user['name']!; } });
            })),
          ])),
      ));
    },
  );
}
