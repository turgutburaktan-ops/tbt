import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminSpotSubmissionsScreen extends StatefulWidget {
  const AdminSpotSubmissionsScreen({super.key});
  @override
  State<AdminSpotSubmissionsScreen> createState() => _AdminSpotSubmissionsScreenState();
}

class _AdminSpotSubmissionsScreenState extends State<AdminSpotSubmissionsScreen> {
  String? _workingId;

  Future<void> _review(String id, String decision) async {
    if (_workingId != null) return;
    String reason = '';
    if (decision != 'approved') {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(decision == 'duplicate' ? 'Mükerrer işaretle' : 'Öneriyi reddet'),
          content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Açıklama / neden')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onayla')),
          ],
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (ok != true) return;
    }
    setState(() => _workingId = id);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('reviewSpotSuggestion').call({
        'submissionId': id,
        'decision': decision,
        'reason': reason,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(decision == 'approved' ? 'Yer yayınlandı.' : 'Öneri sonuçlandırıldı.')));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'İşlem başarısız.')));
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Yeni Yer Önerileri')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('spot_submissions').where('status', isEqualTo: 'pending_review').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Öneriler yüklenemedi.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snapshot.data!.docs]..sort((a, b) {
          final at = a.data()['createdAt'] as Timestamp?;
          final bt = b.data()['createdAt'] as Timestamp?;
          return (bt?.millisecondsSinceEpoch ?? 0).compareTo(at?.millisecondsSinceEpoch ?? 0);
        });
        if (docs.isEmpty) return const Center(child: Text('İncelemede yeni gezilecek yer önerisi yok.', style: TextStyle(color: Colors.white60)));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data();
            final image = (d['imageUrl'] ?? '').toString();
            final busy = _workingId == doc.id;
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (image.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(image, height: 190, width: double.infinity, fit: BoxFit.cover)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Text((d['name'] ?? 'Gezilecek Yer').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    if (d['duplicateWarning'] == true) const Chip(label: Text('Benzer kayıt')),
                  ]),
                  Text('${d['city'] ?? ''}${(d['district'] ?? '').toString().isEmpty ? '' : ' • ${d['district']}'}', style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text((d['description'] ?? '').toString(), style: const TextStyle(color: Colors.white70, height: 1.35)),
                  const SizedBox(height: 6),
                  Text('Neden görülmeli: ${(d['whyVisit'] ?? '').toString()}', style: const TextStyle(color: Colors.white54, height: 1.35)),
                  const SizedBox(height: 7),
                  Text('${d['latitude']}, ${d['longitude']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: busy ? null : () => _review(doc.id, 'approved'), icon: const Icon(Icons.check_rounded), label: const Text('Onayla'))),
                    const SizedBox(width: 7),
                    IconButton.filledTonal(onPressed: busy ? null : () => _review(doc.id, 'duplicate'), tooltip: 'Mükerrer', icon: const Icon(Icons.content_copy_rounded)),
                    const SizedBox(width: 5),
                    IconButton.filledTonal(onPressed: busy ? null : () => _review(doc.id, 'rejected'), tooltip: 'Reddet', icon: const Icon(Icons.close_rounded)),
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
