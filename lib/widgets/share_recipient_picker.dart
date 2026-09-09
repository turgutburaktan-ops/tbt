import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/social_service.dart';

String recipientSearchKey(String value) => value.trim().replaceFirst(RegExp(r'^@'), '')
    .replaceAll('İ', 'i').toLowerCase().replaceAll('ı', 'i')
    .replaceAll('ç', 'c').replaceAll('ğ', 'g').replaceAll('ö', 'o')
    .replaceAll('ş', 's').replaceAll('ü', 'u');

class ShareRecipientPicker extends StatefulWidget {
  const ShareRecipientPicker({super.key, required this.onSelected});
  final ValueChanged<Map<String, String>> onSelected;
  @override
  State<ShareRecipientPicker> createState() => _ShareRecipientPickerState();
}

class _ShareRecipientPickerState extends State<ShareRecipientPicker> {
  final _search = TextEditingController();
  StreamSubscription<List<String>>? _subscription;
  Timer? _debounce;
  final _following = <String>{};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _friends = [], _results = [];
  int _followingRequest = 0, _searchRequest = 0;
  bool _loading = true, _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = SocialService.instance.followingIds().listen(_loadFollowing,
      onError: (Object _) { if (mounted) setState(() { _loading = false; _error = 'Takip edilenler yüklenemedi.'; }); });
  }

  Future<void> _loadFollowing(List<String> ids) async {
    final request = ++_followingRequest;
    _following..clear()..addAll(ids);
    try {
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (var i = 0; i < ids.length; i += 30) {
        final batch = ids.skip(i).take(30).toList();
        final snapshot = await FirebaseFirestore.instance.collection('users')
            .where(FieldPath.documentId, whereIn: batch).get();
        if (!mounted || request != _followingRequest) return;
        docs.addAll(snapshot.docs);
      }
      if (!mounted || request != _followingRequest) return;
      setState(() { _friends = docs; _loading = false; _error = null; });
    } catch (_) {
      if (mounted && request == _followingRequest) setState(() { _loading = false; _error = 'Takip edilenler yüklenemedi.'; });
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    final request = ++_searchRequest;
    setState(() { _results = []; _searching = value.trim().length >= 2; _error = null; });
    if (_searching) _debounce = Timer(const Duration(milliseconds: 300), () => _find(value, request));
  }

  Future<void> _find(String value, int request) async {
    final typed = value.trim().replaceFirst(RegExp(r'^@'), '');
    final variants = {typed, typed.toLowerCase(), typed.split(' ').map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}').join(' ')};
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    final users = FirebaseFirestore.instance.collection('users');
    for (final field in ['displayName', 'name', 'username', 'userName']) {
      for (final prefix in variants) {
        queries.add(users.orderBy(field).startAt([prefix]).endAt(['$prefix\uf8ff']).limit(20).get());
      }
    }
    final normalized = recipientSearchKey(typed);
    queries.add(users.orderBy('usernameNormalized').startAt([normalized]).endAt(['$normalized\uf8ff']).limit(20).get());
    try {
      final snapshots = await Future.wait(queries);
      if (!mounted || request != _searchRequest) return;
      setState(() { _results = snapshots.expand((s) => s.docs).toList(); _searching = false; });
    } catch (_) {
      if (mounted && request == _searchRequest) setState(() { _searching = false; _error = 'Arama yapılamadı. Tekrar dene.'; });
    }
  }

  String _name(Map<String, dynamic> data) {
    for (final field in ['displayName', 'name', 'username', 'userName']) {
      final value = (data[field] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Kullanıcı';
  }

  @override
  void dispose() {
    _subscription?.cancel(); _debounce?.cancel(); _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = recipientSearchKey(_search.text);
    final me = FirebaseAuth.instance.currentUser?.uid;
    final byId = {for (final doc in [..._friends, ..._results]) doc.id: doc};
    final users = byId.values.where((doc) {
      final d = doc.data();
      if (doc.id == me || d['accountStatus'] == 'frozen' || d['accountFrozen'] == true) return false;
      return query.isEmpty || ['displayName', 'name', 'username', 'userName'].any((f) => recipientSearchKey((d[f] ?? '').toString()).contains(query));
    }).toList()..sort((a, b) {
      final priority = (_following.contains(b.id) ? 1 : 0) - (_following.contains(a.id) ? 1 : 0);
      return priority != 0 ? priority : recipientSearchKey(_name(a.data())).compareTo(recipientSearchKey(_name(b.data())));
    });
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(
        controller: _search, onChanged: _changed,
        decoration: InputDecoration(hintText: 'İsim veya kullanıcı adı ara', prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Aramayı temizle', icon: const Icon(Icons.close), onPressed: () { _search.clear(); _changed(''); })),
      )),
      if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
      if (_searching) const LinearProgressIndicator(),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : users.isEmpty ? Center(child: Text(query.isEmpty ? 'Takip ettiğin kişiler burada görünür.\nBirini bulmak için isim ara.' : 'Kullanıcı bulunamadı.', textAlign: TextAlign.center))
        : ListView.builder(itemCount: users.length, itemBuilder: (context, index) {
          final doc = users[index], data = doc.data();
          final name = _name(data), photo = (data['photoUrl'] ?? '').toString();
          final username = (data['username'] ?? data['userName'] ?? '').toString();
          return ListTile(
            leading: CircleAvatar(backgroundImage: photo.isEmpty ? null : NetworkImage(photo), child: photo.isEmpty ? const Icon(Icons.person_outline) : null),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([if (username.isNotEmpty) '@${username.replaceFirst('@', '')}', if (_following.contains(doc.id)) 'Takip ediyorsun'].join(' · ')),
            onTap: () => widget.onSelected({'id': doc.id, 'name': name}),
          );
        })),
    ]);
  }
}
