import 'package:flutter/material.dart';
import '../services/venue_quality_service.dart';

class VenueQualityAdminScreen extends StatefulWidget {
  const VenueQualityAdminScreen({super.key});
  @override
  State<VenueQualityAdminScreen> createState() => _VenueQualityAdminScreenState();
}
class _VenueQualityAdminScreenState extends State<VenueQualityAdminScreen> {
  final List<Map<String, dynamic>> _items = [];
  String _filter = 'pending';
  String? _cursor, _error;
  bool _busy = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await VenueQualityService.call('adminList', {'filter': _filter, if (more) 'cursor': _cursor});
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll((result['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        _cursor = result['cursor'] as String?;
      });
    } catch (e) { if (mounted) setState(() => _error = VenueQualityService.error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF081426),
    appBar: AppBar(title: const Text('TBT Mekân Unvanları'), actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Koşulları sağlayan mekânları incele. Puanı, kişi sayısını ve süreyi atlayarak unvan verilemez.'),
      Wrap(spacing: 8, children: {'pending': 'İnceleme bekleyen', 'all': 'Tümü', 'suspended': 'Askıdakiler'}.entries.map((e) => ChoiceChip(label: Text(e.value), selected: _filter == e.key, onSelected: _busy ? null : (_) { setState(() => _filter = e.key); _load(); })).toList()),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (!_busy && _error == null && _items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Bu grupta mekân yok.')),
      ..._items.map((item) => Card(color: const Color(0xFF0D1B30), child: ListTile(
        title: Text('${item['venueName'] ?? item['id']}'),
        subtitle: Text('${(item['score'] as num? ?? 0).toStringAsFixed(1)}/100 · ${item['count'] ?? 0} kişi · ${item['spanDays'] ?? 0} gün${item['hasReports'] == true ? '\nŞikâyet kaydı var' : ''}${item['needsReview'] == true ? '\n30 gündür koşulların altında' : ''}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => _VenueQualityDetail(venueKey: item['id'] as String)));
          if (mounted) _load();
        },
      ))),
      if (_cursor != null) TextButton(onPressed: _busy ? null : () => _load(more: true), child: const Text('Daha fazla')),
    ]),
  );
}
class _VenueQualityDetail extends StatefulWidget {
  final String venueKey;
  const _VenueQualityDetail({required this.venueKey});
  @override
  State<_VenueQualityDetail> createState() => _VenueQualityDetailState();
}
class _VenueQualityDetailState extends State<_VenueQualityDetail> {
  Map<String, dynamic> _data = {};
  bool _busy = false;
  String? _error;
  final _reason = TextEditingController();
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _reason.dispose(); super.dispose(); }
  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final data = await VenueQualityService.call('adminDetail', {'venueKey': widget.venueKey});
      if (mounted) setState(() { _data = data; _error = null; });
    } catch (e) { if (mounted) setState(() => _error = VenueQualityService.error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _moreReviews() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await VenueQualityService.call('adminReviews', {'venueKey': widget.venueKey, 'cursor': _data['reviewCursor']});
      if (mounted) setState(() {
        _data['reviews'] = [...(_data['reviews'] as List? ?? []), ...(result['reviews'] as List)];
        _data['reviewCursor'] = result['cursor'];
      });
    } catch (e) { if (mounted) setState(() => _error = VenueQualityService.error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _action(String action, Map<String, dynamic> args) async {
    if (_busy) return;
    if (_reason.text.trim().length < 10) { setState(() => _error = 'Karar gerekçesini en az 10 karakterle yaz.'); return; }
    setState(() => _busy = true);
    try {
      await VenueQualityService.call(action, {'venueKey': widget.venueKey, 'reason': _reason.text.trim(), ...args});
      if (!mounted) return;
      _reason.clear();
      await _load();
    } catch (e) { if (mounted) setState(() => _error = VenueQualityService.error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  List<Map<String, dynamic>> _rows(String key) => (_data[key] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  @override
  Widget build(BuildContext context) {
    final item = _data['item'] as Map? ?? {}, criteria = item['criteria'] as Map? ?? {};
    final candidate = (item['candidate'] as num? ?? 0).toInt().clamp(0, 3), award = (item['award'] as num? ?? 0).toInt().clamp(0, 3);
    return Scaffold(backgroundColor: const Color(0xFF081426), appBar: AppBar(title: const Text('Mekân incelemesi'), actions: [IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh))]), body: ListView(padding: const EdgeInsets.all(16), children: [
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
      Text('${item['venueName'] ?? widget.venueKey}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text('Mevcut unvan: ${award == 0 ? 'Yok' : VenueQualityService.labels[award]}${item['suspended'] == true ? ' (askıda)' : ''}'),
      Text('Uygun olduğu unvan: ${candidate == 0 ? 'Henüz yok' : VenueQualityService.labels[candidate]}'),
      Text('${(item['score'] as num? ?? 0).toStringAsFixed(2)}/100 · ${item['count'] ?? 0} ziyaretçi · ${item['spanDays'] ?? 0} gün · son 90 günde ${item['recentCount'] ?? 0} ziyaretçi'),
      ...VenueQualityService.criteria(widget.venueKey.split(':').first).entries.map((e) => ListTile(contentPadding: EdgeInsets.zero, title: Text(e.value), trailing: Text('${(criteria[e.key] as num? ?? 0).toStringAsFixed(1)}/100'))),
      const Text('Temizlik ≥80; son 90 günde ≥5 kişi. Öneriyor ≥80 / 15 kişi / 30 gün. Seçkisi ≥88 / 40 kişi / 90 gün ve her ölçüt ≥75. İmzası ≥94 / 80 kişi / 180 gün ve her ölçüt ≥85.'),
      TextField(controller: _reason, minLines: 2, maxLines: 5, maxLength: 700, decoration: const InputDecoration(labelText: 'Karar gerekçesi / inceleme bulguları')),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: _busy || candidate == 0 ? null : () => _action('decide', {'decision': 'approve'}), child: Text(candidate == 0 ? 'Şartlar sağlanmıyor' : '${VenueQualityService.labels[candidate]} onayla')),
        TextButton(onPressed: _busy ? null : () => _action('decide', {'decision': 'reject'}), child: const Text('Adayı reddet')),
        TextButton(onPressed: _busy || award == 0 ? null : () => _action('decide', {'decision': 'suspend'}), child: const Text('Unvanı askıya al')),
        TextButton(onPressed: _busy || award == 0 ? null : () => _action('decide', {'decision': 'remove'}), child: const Text('Unvanı kaldır')),
        if (item['hasReports'] == true) TextButton(onPressed: _busy ? null : () => _action('resolveReports', {}), child: const Text('Şikâyet incelemesini kapat')),
      ]),
      const SizedBox(height: 16),
      const Text('Son şikâyetler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ..._rows('reports').map((r) => ListTile(title: Text('${r['reason']}'), subtitle: Text('${r['userId']}'))),
      if (_rows('exclusions').isNotEmpty) const Text('Hesaplama dışında tutulanlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ..._rows('exclusions').map((r) => ListTile(title: Text('${r['id']}'), subtitle: Text('${r['reason']}'), trailing: TextButton(onPressed: _busy ? null : () => _action('moderate', {'reviewUid': r['id'], 'excluded': false}), child: const Text('Kısıtı kaldır')))),
      const Text('Doğrulanmış değerlendirmeler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ..._rows('reviews').map((r) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['id']}'),
        Text('Kanıt: ${{'coupon': 'Kullanılmış kupon', 'reservation': 'Tamamlanmış rezervasyon', 'qr': 'Ziyaret QR'}[r['proofType']] ?? r['proofType']}'),
        Text(VenueQualityService.criteria(widget.venueKey.split(':').first).entries.map((e) => '${e.value}: ${(r['scores'] as Map? ?? {})[e.key] ?? '—'}/5').join(' · ')),
        TextButton(onPressed: _busy ? null : () => _action('moderate', {'reviewUid': r['id'], 'excluded': r['excluded'] != true}), child: Text(r['excluded'] == true ? 'Yeniden hesaba kat' : 'Hesaplamadan çıkar')),
      ])))),
      if (_data['reviewCursor'] != null) TextButton(onPressed: _busy ? null : _moreReviews, child: const Text('Diğer değerlendirmeler')),
      const Text('Karar geçmişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ..._rows('decisions').map((r) {
        final date = DateTime.fromMillisecondsSinceEpoch((r['atMs'] as num? ?? 0).toInt()).toLocal();
        final label = {'approve': 'Onaylandı', 'reject': 'Reddedildi', 'suspend': 'Askıya alındı', 'remove': 'Unvan kaldırıldı', 'exclude_review': 'Değerlendirme çıkarıldı', 'restore_review': 'Değerlendirme geri alındı', 'resolve_reports': 'Şikâyet incelemesi kapatıldı'}[r['action']] ?? r['action'];
        return ListTile(title: Text('$label · ${date.day}.${date.month}.${date.year}'), subtitle: Text('${r['reason']}\nİşlemi yapan: ${r['by']}'));
      }),
    ]));
  }
}
