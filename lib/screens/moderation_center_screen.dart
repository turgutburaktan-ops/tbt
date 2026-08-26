import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ModerationCenterScreen extends StatefulWidget {
  const ModerationCenterScreen({super.key});

  @override
  State<ModerationCenterScreen> createState() => _ModerationCenterScreenState();
}

class _ModerationCenterScreenState extends State<ModerationCenterScreen> {
  bool? _admin;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(
      true,
    );
    if (mounted) setState(() => _admin = token?.claims?['admin'] == true);
  }

  @override
  Widget build(BuildContext context) {
    if (_admin == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_admin != true)
      return const Scaffold(
        body: Center(child: Text('Yalnız yöneticiler erişebilir.')),
      );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderasyon Merkezi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Şikâyetler'),
              Tab(text: 'Veri Talepleri'),
              Tab(text: 'İşletmeler'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ReportsQueue(), _DeletionQueue(), _BusinessTrustQueue()],
        ),
      ),
    );
  }
}

class _ReportsQueue extends StatelessWidget {
  const _ReportsQueue();

  Future<void> _resolve(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    await ref.update({
      'status': status,
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('moderation_reports')
        .where('status', isEqualTo: 'open')
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs;
      if (docs.isEmpty) return const Center(child: Text('Açık şikâyet yok.'));
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final d = doc.data();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d['targetType'] ?? 'İçerik'} • ${d['targetId'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text('Neden: ${d['reason'] ?? '-'}'),
                  if ((d['details'] ?? '').toString().isNotEmpty)
                    Text('Detay: ${d['details']}'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _resolve(doc.reference, 'dismissed'),
                          child: const Text('Kapat'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _resolve(doc.reference, 'actioned'),
                          child: const Text('İşlem Yapıldı'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _DeletionQueue extends StatelessWidget {
  const _DeletionQueue();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('account_delete_requests')
        .where('status', isEqualTo: 'requested')
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final docs = snapshot.data!.docs;
      if (docs.isEmpty)
        return const Center(child: Text('Bekleyen hesap silme talebi yok.'));
      return ListView(
        padding: const EdgeInsets.all(12),
        children: docs.map((doc) {
          final d = doc.data();
          return Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text('Kullanıcı: ${d['uid'] ?? doc.id}'),
              subtitle: Text((d['reason'] ?? 'Neden belirtilmedi').toString()),
              trailing: FilledButton(
                onPressed: () => doc.reference.update({
                  'status': 'reviewing',
                  'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
                  'updatedAt': FieldValue.serverTimestamp(),
                }),
                child: const Text('İncele'),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class _BusinessTrustQueue extends StatelessWidget {
  const _BusinessTrustQueue();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collectionGroup('trust_reports')
            .where('status', isEqualTo: 'open')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('Açık işletme güven raporu yok.'));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: docs.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('İşletme güven bildirimi'),
                  subtitle: Text((d['reason'] ?? '-').toString()),
                  trailing: FilledButton(
                    onPressed: () => doc.reference.update({
                      'status': 'reviewing',
                      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }),
                    child: const Text('İncele'),
                  ),
                ),
              );
            }).toList(),
          );
        },
      );
}
