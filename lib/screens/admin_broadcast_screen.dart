import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/admin_console_service.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;
  String? _requestId;
  String? _payload;
  String? _lastBroadcastId;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Herkese gönderilsin mi?'),
        content: const Text('Bu duyuru TBT adına bildirim merkezlerine eklenecek. Telefon bildirimi yalnız tanıtım izni verenlere gönderilir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gönder')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) { setState(() => _sending = false); return; }
    final payload = '${_title.text.trim()}\n${_body.text.trim()}';
    if (_payload != payload || _requestId == null) {
      _payload = payload;
      _requestId = FirebaseFirestore.instance.collection('admin_broadcasts').doc().id;
    }
    try {
      final result = await AdminConsoleService.instance.sendBroadcast(
        requestId: _requestId!, title: _title.text.trim(), body: _body.text.trim());
      if (!mounted) return;
      setState(() => _lastBroadcastId = result['broadcastId'] as String);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duyuru gönderim sırasına alındı. Durumunu aşağıdan takip edebilirsin.')));
      _title.clear();
      _body.clear();
      _requestId = null;
      _payload = null;
    } on FirebaseFunctionsException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Duyuru gönderilemedi.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderim doğrulanamadı. Tekrar denediğinde aynı duyuru ikinci kez oluşturulmaz.')));
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
        const Text('Mesaj, bildirim merkezinde TBT adıyla görünür. Telefon bildirimi yalnız tanıtım bildirimlerine izin verenlere iletilir.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        TextField(enabled: !_sending, controller: _title, maxLength: 100, decoration: const InputDecoration(labelText: 'Başlık')),
        const SizedBox(height: 12),
        TextField(enabled: !_sending, controller: _body, minLines: 5, maxLines: 9, maxLength: 600, decoration: const InputDecoration(labelText: 'Mesaj')),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
          label: Text(_sending ? 'Gönderiliyor…' : 'TBT Adına Herkese Gönder'),
        ),
        if (_lastBroadcastId != null) StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('admin_broadcasts').doc(_lastBroadcastId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Padding(padding: EdgeInsets.only(top: 20), child: Text('Gönderim durumu şu anda okunamıyor.'));
            final data = snapshot.data?.data();
            final done = data?['status'] == 'completed';
            return Padding(padding: const EdgeInsets.only(top: 20), child: Text(
              '${done ? 'Tamamlandı' : 'Gönderim sırasında'} · ${data?['recipientCount'] ?? 0} bildirim merkezine eklendi. Telefon teslim sayısı değildir.',
            ));
          },
        ),
      ],
    ),
  );
}
