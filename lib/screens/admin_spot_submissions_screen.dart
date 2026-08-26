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
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('listPendingSpotSuggestions')
          .call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final raw = (data['items'] as List?) ?? const [];
      if (mounted) setState(() => _items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Öneriler yüklenemedi.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Öneriler yüklenemedi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      await _load();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'İşlem başarısız.')));
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Yeni Yer Önerileri'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
            : _items.isEmpty
                ? const Center(child: Text('İncelemede yeni gezilecek yer önerisi yok.', style: TextStyle(color: Colors.white60)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final d = _items[index];
                      final id = (d['id'] ?? '').toString();
                      final image = (d['imageUrl'] ?? '').toString();
                      final busy = _workingId == id;
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
                              Expanded(child: FilledButton.icon(onPressed: busy ? null : () => _review(id, 'approved'), icon: const Icon(Icons.check_rounded), label: const Text('Onayla'))),
                              const SizedBox(width: 7),
                              IconButton.filledTonal(onPressed: busy ? null : () => _review(id, 'duplicate'), tooltip: 'Mükerrer', icon: const Icon(Icons.content_copy_rounded)),
                              const SizedBox(width: 5),
                              IconButton.filledTonal(onPressed: busy ? null : () => _review(id, 'rejected'), tooltip: 'Reddet', icon: const Icon(Icons.close_rounded)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
  );
}
