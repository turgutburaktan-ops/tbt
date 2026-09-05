import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Herkese gönderilsin mi?'),
        content: const Text('Bu duyuru TBT adına tüm kullanıcılara iletilecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gönder')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('sendAdminBroadcast')
          .call({'title': _title.text.trim(), 'body': _body.text.trim()});
      final count = (result.data as Map?)?['recipientCount'] ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duyuru $count kullanıcıya gönderildi.')));
      _title.clear();
      _body.clear();
    } on FirebaseFunctionsException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Duyuru gönderilemedi.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('TBT Duyurusu')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Tüm kullanıcılara mesaj', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Mesaj, bildirim merkezinde TBT adıyla görünür ve cihaz bildirimi olarak iletilir.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        TextField(controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'Başlık')),
        const SizedBox(height: 12),
        TextField(controller: _body, minLines: 5, maxLines: 9, maxLength: 600, decoration: const InputDecoration(labelText: 'Mesaj')),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
          label: Text(_sending ? 'Gönderiliyor…' : 'TBT Adına Herkese Gönder'),
        ),
      ],
    ),
  );
}
