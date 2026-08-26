import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _db = FirebaseFirestore.instance;
  bool _loading = false;
  List<Map<String, dynamic>> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim().toLowerCase();
    if (q.length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final output = <Map<String, dynamic>>[];
      final users = await _db.collection('users').limit(40).get();
      for (final doc in users.docs) {
        final d = doc.data();
        final hay =
            '${d['username'] ?? ''} ${d['displayName'] ?? ''} ${d['city'] ?? ''}'
                .toLowerCase();
        if (hay.contains(q)) {
          output.add({
            'type': 'Kullanıcı',
            'id': doc.id,
            'title': d['displayName'] ?? d['username'] ?? 'Kullanıcı',
            'subtitle': '@${d['username'] ?? ''}',
          });
        }
      }
      final events = await _db
          .collection('social_events')
          .where('status', isEqualTo: 'open')
          .limit(50)
          .get();
      for (final doc in events.docs) {
        final d = doc.data();
        final hay =
            '${d['title'] ?? ''} ${d['description'] ?? ''} ${d['city'] ?? ''} ${d['category'] ?? ''}'
                .toLowerCase();
        if (hay.contains(q)) {
          output.add({
            'type': 'Etkinlik',
            'id': doc.id,
            'title': d['title'] ?? 'Etkinlik',
            'subtitle': d['city'] ?? '',
          });
        }
      }
      final venues = await _db.collection('business_venues').limit(50).get();
      for (final doc in venues.docs) {
        final d = doc.data();
        final hay = '${d['venueName'] ?? ''} ${d['category'] ?? ''}'
            .toLowerCase();
        if (hay.contains(q)) {
          output.add({
            'type': 'Mekan',
            'id': doc.id,
            'title': d['venueName'] ?? 'Mekan',
            'subtitle': d['category'] ?? '',
          });
        }
      }
      if (mounted) setState(() => _results = output.take(60).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TBT’de Ara')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Kullanıcı, etkinlik, şehir veya mekan ara',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('Aramak için en az 2 karakter yaz.'))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text((item['type'] as String).substring(0, 1)),
                        ),
                        title: Text(
                          item['title'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('${item['type']} • ${item['subtitle']}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
