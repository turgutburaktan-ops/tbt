import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  final Map<String, String> _selected = {};
  late final _users = FirebaseFirestore.instance.collection('users').limit(300).snapshots();
  bool _details = false, _saving = false;
  static const _background = Color(0xFF090A0C);
  static const _accent = Color(0xFF55D6D0);

  @override
  void dispose() { _name.dispose(); _search.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (_saving || _selected.isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final result = await ChatService.instance.action('create', {
        'name': _name.text.trim(), 'memberIds': _selected.keys.toList(),
      });
      if (mounted) Navigator.pop(context, result['threadId'] as String);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(primary: _accent, surface: _background),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false, border: UnderlineInputBorder(),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)),
      ),
    ),
    child: PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background, foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _saving ? null : () {
            if (_details) { setState(() => _details = false); } else { Navigator.pop(context); }
          }),
          title: Text(_details ? 'Yeni grup' : 'Kişileri seç'),
          actions: [TextButton(
            onPressed: _saving || _selected.isEmpty || (_details && _name.text.trim().isEmpty) ? null : () {
              if (_details) { _create(); } else { setState(() => _details = true); }
            },
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_details ? 'Oluştur' : 'İleri'),
          )],
        ),
        body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: Text(
            '${_selected.length} kişi seçildi · Sen de gruba dahilsin',
            style: const TextStyle(color: Colors.white54),
          )),
          if (_details)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(
              controller: _name, autofocus: true, maxLength: 80, enabled: !_saving,
              style: const TextStyle(fontSize: 22, color: Colors.white),
              decoration: const InputDecoration(hintText: 'Grubuna bir ad ver'),
              onChanged: (_) => setState(() {}),
            ))
          else
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: TextField(
              controller: _search, onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'İsim veya kullanıcı adı ara'),
            )),
          if (_details)
            Expanded(child: ListView(children: _selected.entries.map((e) => ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF1A2326), child: Icon(Icons.person_outline, color: _accent)),
              title: Text(e.value),
              trailing: IconButton(tooltip: 'Seçimden çıkar', icon: const Icon(Icons.close), onPressed: _saving ? null : () => setState(() => _selected.remove(e.key))),
            )).toList()))
          else
            Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _users,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Kişiler yüklenemedi. Lütfen tekrar dene.'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final query = _search.text.trim().toLowerCase();
                final users = snapshot.data!.docs.where((d) {
                  final u = d.data();
                  return d.id != FirebaseAuth.instance.currentUser?.uid && u['isEditorial'] != true &&
                    [u['displayName'], u['name'], u['username']].any((v) => (v ?? '').toString().toLowerCase().contains(query));
                }).toList();
                if (users.isEmpty) return const Center(child: Text('Kullanıcı bulunamadı.'));
                return ListView.builder(itemCount: users.length, itemBuilder: (_, i) {
                  final doc = users[i], u = doc.data();
                  final name = (u['displayName'] ?? u['name'] ?? u['username'] ?? 'Kullanıcı').toString();
                  final selected = _selected.containsKey(doc.id);
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFF1A2326), child: Icon(Icons.person_outline, color: _accent)),
                    title: Text(name), subtitle: Text((u['username'] ?? '').toString()),
                    trailing: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? _accent : Colors.white38),
                    onTap: () {
                      if (!selected && _selected.length >= 49) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En fazla 49 kişi seçebilirsin.'))); return;
                      }
                      setState(() { if (selected) { _selected.remove(doc.id); } else { _selected[doc.id] = name; } });
                    },
                  );
                });
              },
            )),
        ])),
      ),
    ),
  );
}
