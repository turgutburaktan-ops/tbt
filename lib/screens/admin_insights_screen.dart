import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminInsightsScreen extends StatefulWidget {
  const AdminInsightsScreen({super.key});

  @override
  State<AdminInsightsScreen> createState() => _AdminInsightsScreenState();
}

class _AdminInsightsScreenState extends State<AdminInsightsScreen> {
  bool? _allowed;
  bool _loading = false;
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    final ok = token?.claims?['admin'] == true;
    if (!mounted) return;
    setState(() => _allowed = ok);
    if (ok) await _load();
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final value = await query.count().get();
    return value.count ?? 0;
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      final values = await Future.wait<int>([
        _count(db.collection('moderation_reports').where('status', isEqualTo: 'open')),
        _count(db.collection('account_delete_requests').where('status', isEqualTo: 'requested')),
        _count(db.collection('analytics_events')),
        _count(db.collection('app_errors')),
        _count(db.collectionGroup('trust_reports').where('status', isEqualTo: 'open')),
      ]);
      if (mounted) {
        setState(() => _counts = {
          'Açık şikâyet': values[0],
          'Hesap silme talebi': values[1],
          'Analitik olayı': values[2],
          'Uygulama hatası': values[3],
          'İşletme güven raporu': values[4],
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == null) return const Center(child: CircularProgressIndicator());
    if (_allowed != true) return const Center(child: Text('Yönetici yetkisi gerekli.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Operasyon ve kalite', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Güvenlik, veri talepleri ve uygulama sağlığını tek yerden takip et.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          if (_loading && _counts.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            ..._counts.entries.map((e) => Card(
              child: ListTile(
                title: Text(e.key),
                trailing: Text('${e.value}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ),
            )),
          const SizedBox(height: 16),
          const Text('Son uygulama hataları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('app_errors').orderBy('createdAt', descending: true).limit(20).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              if (snap.data!.docs.isEmpty) return const Text('Kayıtlı hata yok.', style: TextStyle(color: Colors.white54));
              return Column(children: snap.data!.docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.error_outline_rounded),
                  title: Text((d['context'] ?? 'Uygulama').toString()),
                  subtitle: Text((d['error'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                );
              }).toList());
            },
          ),
        ],
      ),
    );
  }
}
