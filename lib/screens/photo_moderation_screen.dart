import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _photoFunctions = FirebaseFunctions.instanceFor(region: 'europe-west1');

class PhotoModerationScreen extends StatefulWidget {
  const PhotoModerationScreen({super.key, this.admin = false});
  final bool admin;
  @override
  State<PhotoModerationScreen> createState() => _PhotoModerationScreenState();
}

class _PhotoModerationScreenState extends State<PhotoModerationScreen> {
  String _filter = 'review';
  bool _busy = false;
  int _limit = 50;
  bool get _accounts => _filter == 'accounts';

  Future<void> _action(String name, Map<String, dynamic> data, String label) async {
    var typedReason = ''; 
    final why = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text(label),
      content: TextField(onChanged: (v) => typedReason = v, maxLength: 500, maxLines: 4,
        decoration: const InputDecoration(labelText: 'Gerekçe (en az 5 karakter)')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
        FilledButton(onPressed: () {
          if (typedReason.trim().length >= 5) Navigator.pop(c, typedReason.trim());
        }, child: const Text('Gönder'))],
    ));
    if (why == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _photoFunctions.httpsCallable(name,
        options: HttpsCallableOptions(timeout: const Duration(minutes: 5)))
        .call({...data, 'reason': why});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem alındı.')));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'İşlem tamamlanamadı.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantıyı kontrol edip tekrar dene.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _preview(String id) async {
    setState(() => _busy = true);
    try {
      final result = await _photoFunctions.httpsCallable('photoModerationPreview').call({'id': id});
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (c) => Dialog(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Flexible(child: InteractiveViewer(child: Image.memory(base64Decode(result.data['base64'] as String),
          errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Görsel yüklenemedi.'))))),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Kapat'))],
      )));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önizleme açılamadı. Tekrar dene.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  String _status(Map<String, dynamic> d) {
    const labels = {'scanning': 'Arka planda denetleniyor', 'clear': 'Uygun', 'review': 'Admin incelemesinde',
      'confirmed': 'İhlal doğrulandı', 'dismissed': 'İhlal kaldırıldı', 'deleted': 'Paylaşım silindi',
      'pending': 'Kapatma onayı bekliyor', 'closing': 'Hesap kapatılıyor', 'closed': 'Hesap kapalı',
      'reopening': 'Hesap geri açılıyor', 'rejected': 'Hesap açık', 'none': 'Hesap açık'};
    return labels[d[_accounts ? 'closureStatus' : 'status']] ?? 'İnceleniyor';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      _accounts ? 'photo_moderation_accounts' : 'photo_moderation');
    if (!widget.admin) {
      query = query.where('userId', isEqualTo: uid ?? 'signed_out');
    } else if (_filter == 'appeals') {
      query = query.where('appealStatus', isEqualTo: 'pending');
    } else if (!_accounts) {
      query = query.where('status', isEqualTo: _filter);
    }
    query = query.orderBy('updatedAt', descending: true).limit(_limit);
    return Scaffold(
      appBar: AppBar(title: Text(widget.admin ? 'Fotoğraf denetimi' : 'Paylaşım denetimi')),
      body: Column(children: [
        if (_busy) const LinearProgressIndicator(),
        Padding(padding: const EdgeInsets.all(16), child: Text(widget.admin
          ? 'Paylaşımlar anında yayınlanır. Otomatik tespit tek başına ihlal sayılmaz. Beş doğrulanmış paylaşımda hesap kapatma kararını sen verirsin.'
          : 'Fotoğraflar paylaşımdan sonra denetlenir. Gizlenen veya ihlal olarak değerlendirilen paylaşımlarına buradan itiraz edebilirsin.')),
        if (widget.admin) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: DropdownButton<String>(
          isExpanded: true, value: _filter,
          items: const [DropdownMenuItem(value: 'review', child: Text('İncelenecek fotoğraflar')),
            DropdownMenuItem(value: 'appeals', child: Text('Fotoğraf itirazları')),
            DropdownMenuItem(value: 'confirmed', child: Text('Doğrulanmış ihlaller')),
            DropdownMenuItem(value: 'dismissed', child: Text('Kaldırılan ihlaller')),
            DropdownMenuItem(value: 'accounts', child: Text('Hesap kararları ve itirazları'))],
          onChanged: _busy ? null : (v) => setState(() { _filter = v!; _limit = 50; }),
        )),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(), builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Liste yüklenemedi. Yetki veya bağlantıyı kontrol et.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('Bekleyen kayıt yok.'));
            return ListView(children: [for (final doc in docs) _card(doc),
              if (docs.length >= _limit) TextButton(onPressed: () => setState(() => _limit += 50), child: const Text('Daha fazla göster'))]);
          },
        )),
      ]),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Padding(
      padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_status(d), style: const TextStyle(fontWeight: FontWeight.bold)),
        if (widget.admin) SelectableText('Kullanıcı: ${d['userId']}'),
        if (_accounts) Text('Doğrulanmış ihlal: ${d['strikes'] ?? 0}'),
        if (!_accounts) Text(d['desiredHidden'] == true ? 'Paylaşım gizlendi.' : 'Paylaşım görünür.'),
        if (d['decisionReason'] != null) Text('Gerekçe: ${d['decisionReason']}'),
        if (d['appealReason'] != null) Text('İtiraz: ${d['appealReason']}'),
        if (d['appealStatus'] == 'pending') const Text('İtiraz yanıt bekliyor.'),
        if (d['lastError'] != null) const Text('Denetim servisi tekrar deniyor; ihlal sayılmadı.'),
        if (widget.admin && d['scores'] != null) Text('Tespit: ${d['scores']['adult']} / ${d['scores']['racy']}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (widget.admin && !_accounts) OutlinedButton(onPressed: _busy ? null : () => _preview(doc.id), child: const Text('Fotoğrafı incele')),
          if (widget.admin && !_accounts) ...[
            FilledButton(onPressed: _busy ? null : () => _action('reviewPhotoModeration', {'id': doc.id, 'action': 'confirm'}, 'İhlali doğrula'), child: const Text('İhlali doğrula')),
            OutlinedButton(onPressed: _busy ? null : () => _action('reviewPhotoModeration', {'id': doc.id, 'action': 'dismiss'}, 'İhlali kaldır'), child: const Text('İhlali kaldır')),
          ],
          if (widget.admin && _accounts && d['closureStatus'] == 'pending') ...[
            FilledButton(onPressed: _busy ? null : () => _action('reviewPhotoAccount', {'uid': doc.id, 'action': 'approve'}, 'Hesabı kapatmayı onayla'), child: const Text('Hesabı kapat')),
            OutlinedButton(onPressed: _busy ? null : () => _action('reviewPhotoAccount', {'uid': doc.id, 'action': 'reject'}, 'Hesap açık kalsın'), child: const Text('Açık kalsın')),
          ],
          if (widget.admin && _accounts && d['closureStatus'] == 'closed') OutlinedButton(
            onPressed: _busy ? null : () => _action('reviewPhotoAccount', {'uid': doc.id, 'action': 'reopen'}, 'Hesabı yeniden aç'), child: const Text('Hesabı yeniden aç')),
          if (!widget.admin && ['review', 'confirmed'].contains(d['status']) && !['pending', 'accepted', 'rejected'].contains(d['appealStatus']))
            OutlinedButton(onPressed: _busy ? null : () => _action('appealPhotoModeration', {'id': doc.id}, 'Karara itiraz et'), child: const Text('İtiraz et')),
        ]),
      ]),
    ));
  }
}

class ClosedAccountAppealScreen extends StatefulWidget {
  const ClosedAccountAppealScreen({super.key});
  @override
  State<ClosedAccountAppealScreen> createState() => _ClosedAccountAppealScreenState();
}
class _ClosedAccountAppealScreenState extends State<ClosedAccountAppealScreen> {
  final _code = TextEditingController(), _reason = TextEditingController();
  bool _busy = false;
  @override
  void dispose() { _code.dispose(); _reason.dispose(); super.dispose(); }
  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await _photoFunctions.httpsCallable('appealClosedPhotoAccount').call({'code': _code.text.trim(), 'reason': _reason.text.trim()});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İtirazın admin incelemesine gönderildi.'))); Navigator.pop(context); }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'İtiraz gönderilemedi.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantıyı kontrol edip tekrar dene.')));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Hesap itirazı')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Hesap kapatma bildirimindeki kişisel itiraz kodunu gir. Kodunu başkalarıyla paylaşma.'),
      TextField(controller: _code, decoration: const InputDecoration(labelText: 'İtiraz kodu')),
      TextField(controller: _reason, maxLength: 500, maxLines: 5, decoration: const InputDecoration(labelText: 'İtiraz gerekçesi')),
      FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'Gönderiliyor…' : 'İtirazı gönder')),
    ]));
}
