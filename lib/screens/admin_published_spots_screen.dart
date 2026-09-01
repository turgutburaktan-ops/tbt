import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminPublishedSpotsScreen extends StatefulWidget {
  const AdminPublishedSpotsScreen({super.key});

  @override
  State<AdminPublishedSpotsScreen> createState() =>
      _AdminPublishedSpotsScreenState();
}

class _AdminPublishedSpotsScreenState
    extends State<AdminPublishedSpotsScreen> {
  String _query = '';
  String _status = 'published';
  String? _workingId;

  Future<void> _archive(
    DocumentReference<Map<String, dynamic>> reference,
    bool archive,
  ) async {
    setState(() => _workingId = reference.id);
    try {
      await reference.update({
        'status': archive ? 'archived' : 'published',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _delete(
    DocumentReference<Map<String, dynamic>> reference,
    String name,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mekanı kalıcı sil'),
        content: Text(
          '$name kalıcı olarak silinecek. Önce arşivlemek daha güvenlidir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kalıcı Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    setState(() => _workingId = reference.id);
    try {
      await reference.delete();
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Yayınlanan Mekanlar')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: TextField(
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Mekan, şehir, ilçe veya kategori ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'published', label: Text('Yayında')),
              ButtonSegment(value: 'archived', label: Text('Arşiv')),
            ],
            selected: {_status},
            onSelectionChanged: (value) =>
                setState(() => _status = value.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('photo_spots')
                .where('status', isEqualTo: _status)
                .limit(500)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.where((doc) {
                if (_query.isEmpty) return true;
                final data = doc.data();
                final text = [
                  data['name'],
                  data['city'],
                  data['district'],
                  data['region'],
                  data['category'],
                ].map((item) => (item ?? '').toString().toLowerCase()).join(' ');
                return text.contains(_query);
              }).toList();
              if (docs.isEmpty) {
                return const Center(child: Text('Mekan bulunamadı.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 30),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = (data['name'] ?? 'Mekan').toString();
                  final busy = _workingId == doc.id;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        [
                          data['city'],
                          data['district'] ?? data['region'],
                          data['category'],
                        ]
                            .map((item) => (item ?? '').toString())
                            .where((item) => item.isNotEmpty)
                            .join(' • '),
                      ),
                      trailing: PopupMenuButton<String>(
                        enabled: !busy,
                        onSelected: (value) {
                          if (value == 'archive') {
                            _archive(doc.reference, true);
                          } else if (value == 'restore') {
                            _archive(doc.reference, false);
                          } else if (value == 'delete') {
                            _delete(doc.reference, name);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: _status == 'published'
                                ? 'archive'
                                : 'restore',
                            child: Text(
                              _status == 'published'
                                  ? 'Arşive kaldır'
                                  : 'Yeniden yayınla',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Kalıcı sil'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
