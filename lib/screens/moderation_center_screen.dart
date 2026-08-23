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
    final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    if (mounted) setState(() => _admin = token?.claims?['admin'] == true);
  }

  Future<void> _resolve(DocumentReference<Map<String, dynamic>> ref, String status) async {
    await ref.update({
      'status': status,
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_admin == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_admin != true) return const Scaffold(body: Center(child: Text('Yalnız yöneticiler erişebilir.')));
    return Scaffold(
      appBar: AppBar(title: const Text('Moderasyon Merkezi')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('moderation_reports').where('status', isEqualTo: 'open').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${d['targetType'] ?? 'İçerik'} • ${d['targetId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Neden: ${d['reason'] ?? '-'}'),
                    if ((d['details'] ?? '').toString().isNotEmpty) Text('Detay: ${d['details']}'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => _resolve(doc.reference, 'dismissed'), child: const Text('Kapat'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(onPressed: () => _resolve(doc.reference, 'actioned'), child: const Text('İşlem Yapıldı'))),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
