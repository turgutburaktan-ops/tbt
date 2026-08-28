import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_console_service.dart';
import '../theme/app_theme.dart';
import 'business_panel_preview_screen.dart';

class AdminBusinessesV2Screen extends StatefulWidget {
  const AdminBusinessesV2Screen({super.key});

  @override
  State<AdminBusinessesV2Screen> createState() => _AdminBusinessesV2ScreenState();
}

class _AdminBusinessesV2ScreenState extends State<AdminBusinessesV2Screen> {
  bool? _allowed;
  bool _loading = true;
  String _filter = 'all';
  String _query = '';
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  final Set<String> _reviewing = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _keyFor(Map<String, dynamic> data) {
    final direct = (data['venueKey'] ?? data['id'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final category = (data['category'] ?? '').toString().trim();
    final venueId = (data['venueId'] ?? '').toString().trim();
    if (category.isNotEmpty && venueId.isNotEmpty) return '$category:$venueId';
    return '${data['venueName'] ?? data['legalName'] ?? ''}|$category'.toLowerCase();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      if (token?.claims?['admin'] != true) {
        if (mounted) setState(() { _allowed = false; _loading = false; });
        return;
      }
      final claimsFuture = AdminConsoleService.instance.businessClaims();
      final venuesFuture = FirebaseFirestore.instance.collection('business_venues').limit(1000).get();
      final claims = await claimsFuture;
      final venues = await venuesFuture;
      final merged = <String, Map<String, dynamic>>{};
      for (final doc in venues.docs) {
        final data = doc.data();
        merged[doc.id] = {...data, 'venueKey': doc.id, 'venueName': (data['venueName'] ?? data['name'] ?? 'İşletme').toString(), 'status': data['verified'] == true ? 'verified' : 'registered'};
      }
      for (final raw in claims) {
        final claim = Map<String, dynamic>.from(raw);
        final key = _keyFor(claim);
        merged[key] = {...?merged[key], ...claim, 'venueKey': merged[key]?['venueKey'] ?? claim['venueKey'] ?? key};
      }
      final items = merged.values.toList()..sort((a, b) => (a['venueName'] ?? a['legalName'] ?? '').toString().compareTo((b['venueName'] ?? b['legalName'] ?? '').toString()));
      if (mounted) setState(() { _allowed = true; _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _allowed = true; _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _review(Map<String, dynamic> data, {required bool approve}) async {
    final key = _keyFor(data);
    if (_reviewing.contains(key)) return;
    var reason = '';
    if (!approve) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Başvuruyu reddet'), content: TextField(controller: controller, autofocus: true, minLines: 2, maxLines: 4, maxLength: 500, decoration: const InputDecoration(hintText: 'Red nedeni')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reddet'))]));
      reason = controller.text.trim();
      controller.dispose();
      if (confirmed != true) return;
      if (reason.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Red nedeni yazmalısın.')));
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('İşletmeyi onayla'), content: const Text('Başvuru sahibine bu işletmenin doğrulanmış yönetim yetkisi verilecek.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla'))]));
      if (confirmed != true) return;
    }
    final category = (data['category'] ?? '').toString().trim();
    final venueId = (data['venueId'] ?? '').toString().trim();
    if (category.isEmpty || venueId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Başvurunun mekan kimliği eksik.')));
      return;
    }
    if (!mounted) return;
    setState(() => _reviewing.add(key));
    try {
      await AdminConsoleService.instance.reviewBusinessClaim(category: category, venueId: venueId, approve: approve, reason: reason);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'İşletme onaylandı.' : 'Başvuru reddedildi.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _reviewing.remove(key));
    }
  }

  List<Map<String, dynamic>> get _filtered => _items.where((d) {
    final status = (d['status'] ?? 'registered').toString();
    if (_filter != 'all' && status != _filter) return false;
    if (_query.isEmpty) return true;
    return '${d['venueName'] ?? ''} ${d['legalName'] ?? ''} ${d['businessEmail'] ?? d['ownerEmail'] ?? ''}'.toLowerCase().contains(_query);
  }).toList();

  int _count(String status) => status == 'all' ? _items.length : _items.where((e) => (e['status'] ?? 'registered').toString() == status).length;
  String _status(String s) => s == 'verified' ? 'Onaylı' : s == 'pending_review' ? 'Bekleyen' : s == 'rejected' ? 'Reddedildi' : 'Kayıtlı';

  Future<void> _details(Map<String, dynamic> data) async {
    final status = (data['status'] ?? 'registered').toString();
    final evidenceUrl = (data['evidenceUrl'] ?? '').toString().trim();
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .5,
        maxChildSize: .96,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            Text((data['venueName'] ?? data['legalName'] ?? 'İşletme').toString(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Durum: ${_status(status)}'),
            Text('E-posta: ${data['businessEmail'] ?? data['ownerEmail'] ?? '-'}'),
            Text('Telefon: ${data['businessPhone'] ?? data['phone'] ?? '-'}'),
            Text('Yasal ad: ${data['legalName'] ?? '-'}'),
            const SizedBox(height: 18),
            const Text('Yetki kanıtı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 9),
            if (evidenceUrl.isEmpty)
              const SizedBox(height: 180, child: Center(child: Text('Kanıt görseli bulunamadı.')))
            else
              ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 320, child: InteractiveViewer(minScale: 1, maxScale: 4, child: Image.network(evidenceUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('Kanıt görseli yüklenemedi.')))))),
            const SizedBox(height: 18),
            if (status == 'pending_review')
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(sheetContext, 'reject'), icon: const Icon(Icons.close_rounded), label: const Text('Reddet'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(sheetContext, 'approve'), icon: const Icon(Icons.verified_rounded), label: const Text('Onayla'))),
              ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: () => Navigator.pop(sheetContext, 'preview'), icon: const Icon(Icons.dashboard_customize_outlined), label: const Text('Paneli Görüntüle')),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (action == 'approve') {
      await _review(data, approve: true);
    } else if (action == 'reject') {
      await _review(data, approve: false);
    } else if (action == 'preview') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessPanelPreviewScreen(venueName: (data['venueName'] ?? 'İşletme').toString(), category: (data['category'] ?? 'cafe').toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed == false) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Yönetici yetkisi gerekli.')));
    return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: const Text('İşletmeler'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]), body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
      Row(children: [Expanded(child: _mini('Toplam', _count('all'))), const SizedBox(width: 8), Expanded(child: _mini('Bekleyen', _count('pending_review'))), const SizedBox(width: 8), Expanded(child: _mini('Onaylı', _count('verified')))]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => _query = v.trim().toLowerCase()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'İşletme ara')),
      const SizedBox(height: 10),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_chip('all','Tümü'), _chip('registered','Kayıtlı'), _chip('pending_review','Bekleyen'), _chip('verified','Onaylı'), _chip('rejected','Reddedilen')])),
      const SizedBox(height: 14),
      if (_loading) const Padding(padding: EdgeInsets.only(top: 70), child: Center(child: CircularProgressIndicator())) else if (_error != null) Center(child: Text('İşletmeler yüklenemedi\n$_error', textAlign: TextAlign.center)) else if (_filtered.isEmpty) const Padding(padding: EdgeInsets.only(top: 70), child: Center(child: Text('Bu filtrede işletme yok.'))) else ..._filtered.map((data) { final s=(data['status']??'registered').toString(); return Card(child: ListTile(onTap: () => _details(data), leading: Icon(s=='verified'?Icons.verified_rounded:Icons.storefront_outlined, color:s=='verified'?AppColors.cyan:Colors.white70), title: Text((data['venueName']??data['legalName']??'İşletme').toString(), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(_status(s)), trailing: const Icon(Icons.chevron_right_rounded))); }),
    ])));
  }

  Widget _mini(String label, int count) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(14)), child: Column(children: [Text('$count', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))]));
  Widget _chip(String value, String label) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(selected: _filter == value, onSelected: (_) => setState(() => _filter = value), label: Text('$label  ${_count(value)}')));
}
