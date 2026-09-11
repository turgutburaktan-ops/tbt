import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/venue_quality_service.dart';
import 'tbt_dialog.dart';

class VenueQualitySection extends StatefulWidget {
  final String category, venueId, venueName;
  const VenueQualitySection({super.key, required this.category, required this.venueId, required this.venueName});
  @override
  State<VenueQualitySection> createState() => _VenueQualitySectionState();
}

class _VenueQualitySectionState extends State<VenueQualitySection> {
  Map<String, dynamic> _status = {};
  final Map<String, int> _scores = {};
  bool _busy = false, _loaded = false;
  String? _failure;
  String get _key => '${widget.category}:${widget.venueId}';
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant VenueQualitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venueId != widget.venueId || oldWidget.category != widget.category) {
      _status = {}; _scores.clear(); _loaded = false; _load();
    }
  }
  Future<void> _load() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final key = _key;
    try {
      final result = await VenueQualityService.call('status', {'venueKey': key});
      if (!mounted || key != _key) return;
      setState(() {
        _status = result; _loaded = true; _failure = null;
        _scores.clear();
        final mine = result['mine'] as Map?;
        if (mine != null) { for (final k in VenueQualityService.keys) { _scores[k] = (mine[k] as num).toInt(); } }
      });
    } catch (e) { if (mounted && key == _key) setState(() { _failure = VenueQualityService.error(e); _loaded = true; }); }
  }
  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  Future<void> _perform(String action, [Map<String, dynamic> data = const {}]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await VenueQualityService.call(action, {'venueKey': _key, 'venueName': widget.venueName, ...data});
      await _load();
      _message(action == 'report' ? 'Bildirimin incelemeye alındı.' : 'Kaydedildi.');
    } catch (e) { _message(VenueQualityService.error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _code({bool report = false}) async {
    final value = await showTbtDialog<String>(context: context, builder: (_) => _QualityTextEntry(
      title: report ? 'Mekânla ilgili sorun bildir' : 'Ziyaret kodunu gir',
      hint: report ? 'Yaşadığın sorunu ve ziyaret tarihini açıkla.' : 'İşletmenin verdiği TBT-VISIT kodu',
    ));
    if (value != null && mounted) await _perform(report ? 'report' : 'redeemVisit', {report ? 'reason' : 'token': value});
  }
  Future<void> _scan() async {
    final token = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _VisitScanner()));
    if (token != null && mounted) await _perform('redeemVisit', {'token': token});
  }
  Future<void> _createCode() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await VenueQualityService.call('createVisit', {'venueKey': _key});
      if (!mounted) return;
      await showTbtDialog<void>(context: context, builder: (_) => SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Müşteri ziyaret kodu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          QrImageView(data: data['token'] as String, size: 210, backgroundColor: Colors.white),
          const SizedBox(height: 12), SelectableText(data['token'] as String),
          const SizedBox(height: 12),
          const Text('10 dakika içinde yalnız bir müşteri kullanabilir. Yeni kod oluşturmak önceki kodu iptal eder. Kodu ziyaret sırasında göster.'),
        ]),
      )));
    } catch (e) { _message(VenueQualityService.error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final labels = VenueQualityService.criteria(widget.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0D1B30), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF284763))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TBT Mekân Değerlendirmesi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('venue_quality_public').doc(_key).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('Mekân puanı şu anda yüklenemedi.');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final d = snapshot.data?.data() ?? {}, award = (d['award'] as num? ?? 0).toInt().clamp(0, 3);
            final count = (d['count'] as num? ?? 0).toInt();
            final criteria = d['criteria'] as Map? ?? {};
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (award > 0) Chip(avatar: const Icon(Icons.workspace_premium, color: Color(0xFFFFC857)), label: Text(VenueQualityService.labels[award])),
              if (d['suspended'] == true) const Text('Mekân unvanı inceleme süresince askıda.'),
              Text(count == 0 ? 'Henüz doğrulanmış değerlendirme yok.' : '${(d['score'] as num? ?? 0).toStringAsFixed(1)}/100 · $count doğrulanmış ziyaretçi'),
              if (count > 0) ...labels.entries.map((e) => Padding(padding: const EdgeInsets.only(top: 5), child: Text('${e.value}: ${(criteria[e.key] as num? ?? 0).toStringAsFixed(1)}/100'))),
            ]);
          },
        ),
        const SizedBox(height: 10),
        const Text('Unvanlar doğrulanmış deneyimlere dayanır. Öneriyor: 80 puan / 15 kişi / 30 gün. Seçkisi: 88 / 40 / 90 gün. İmzası: 94 / 80 / 180 gün.', style: TextStyle(fontSize: 12)),
        ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Değerlendirme kuralları'), children: [
          Text(widget.category == 'dining' ? 'Ağırlıklar: kalite %35, temizlik %20, hizmet %20, fiyat karşılığı %15, ortam %10.' : widget.category == 'cafe' ? 'Ağırlıklar: kalite %30, temizlik %20, hizmet %20, fiyat karşılığı %15, ortam %15.' : 'Ağırlıklar: oda %30, temizlik %25, hizmet %20, fiyat karşılığı %15, olanaklar %10.'),
          const Text('Son 12 aydaki ziyaretler hesaplanır. Son 90 gün %60, önceki dönem %40 ağırlıktadır; tek dönem varsa tamamı kullanılır. Her kişinin son değerlendirmesi sayılır. Temizlik en az 80 olmalı; Seçkisi için her ölçüt en az 75, İmzası için 85 olmalı. Son 90 günde en az 5 ziyaretçi gerekir. Süre, ilk ve son ziyaret arasındadır. Koşullar sağlandığında yönetici incelemesi açılır. Reklam, paket veya hesap türü puanı etkilemez.'),
        ]),
        if (!_loaded) const LinearProgressIndicator(),
        if (_failure != null) TextButton(onPressed: _load, child: Text('$_failure Tekrar dene')),
        if (_status['owner'] == true) OutlinedButton.icon(onPressed: _busy ? null : _createCode, icon: const Icon(Icons.qr_code), label: const Text('Müşteri için ziyaret kodu oluştur')),
        if (_status['affiliated'] == true) const Text('İşletme sahibi ve çalışanlar kendi mekânını puanlayamaz.'),
        if (_status['eligible'] == true && _status['excluded'] != true) ...[
          const Text('1: ciddi sorun · 2: beklentinin altında · 3: beklentiyi karşıladı · 4: çok iyi · 5: mükemmel', style: TextStyle(fontSize: 12)),
          ...labels.entries.map((e) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(e.value)),
            Wrap(spacing: 8, children: List.generate(5, (i) => ChoiceChip(label: Text('${i + 1}'), selected: _scores[e.key] == i + 1, onSelected: _busy ? null : (_) => setState(() => _scores[e.key] = i + 1)))),
          ])),
          FilledButton(onPressed: _busy || _scores.length != 5 ? null : () => _perform('submit', {'scores': _scores}), child: Text(_status['mine'] == null ? 'Doğrulanmış değerlendirme yap' : 'Değerlendirmemi güncelle')),
        ],
        if (_status['excluded'] == true) const Text('Değerlendirmen incelemede.'),
        if (_status['mine'] != null) TextButton(onPressed: _busy ? null : () => _perform('delete'), child: const Text('Doğrulanmış değerlendirmemi sil')),
        if (_loaded && _failure == null && _status['eligible'] != true && _status['affiliated'] != true) const Text('Puan vermek için kullanılmış kupon, tamamlanmış rezervasyon veya işletmeden ziyaret kodu gerekir.'),
        if (FirebaseAuth.instance.currentUser != null && _status['affiliated'] != true) Wrap(spacing: 8, children: [
          TextButton.icon(onPressed: _busy ? null : _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Ziyaret QR oku')),
          TextButton(onPressed: _busy ? null : () => _code(), child: const Text('Kod gir')),
        ]),
        if (FirebaseAuth.instance.currentUser != null) TextButton(onPressed: _busy ? null : () => _code(report: true), child: const Text('Sorun bildir')),
        if (_busy) const LinearProgressIndicator(),
      ]),
    );
  }
}

class _QualityTextEntry extends StatefulWidget {
  final String title, hint;
  const _QualityTextEntry({required this.title, required this.hint});
  @override
  State<_QualityTextEntry> createState() => _QualityTextEntryState();
}
class _QualityTextEntryState extends State<_QualityTextEntry> {
  final _text = TextEditingController();
  @override
  void dispose() { _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    TextField(controller: _text, maxLength: 700, minLines: 1, maxLines: 5, decoration: InputDecoration(hintText: widget.hint)),
    FilledButton(onPressed: () { if (_text.text.trim().isNotEmpty) Navigator.pop(context, _text.text.trim()); }, child: const Text('Gönder')),
  ])));
}
class _VisitScanner extends StatefulWidget {
  const _VisitScanner();
  @override
  State<_VisitScanner> createState() => _VisitScannerState();
}
class _VisitScannerState extends State<_VisitScanner> {
  bool _done = false;
  final _controller = MobileScannerController();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Ziyaret QR oku')), body: MobileScanner(controller: _controller, onDetect: (capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final token = barcode.rawValue ?? '';
      if (RegExp(r'^TBT-VISIT-[A-F0-9]{32}$').hasMatch(token)) { _done = true; Navigator.pop(context, token); break; }
    }
  }));
}
