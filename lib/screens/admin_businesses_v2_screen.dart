import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_console_service.dart';
import '../theme/app_theme.dart';
import 'business_hub_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      final allowed = token?.claims?['admin'] == true;
      if (!allowed) {
        if (mounted) setState(() { _allowed = false; _loading = false; });
        return;
      }
      final items = await AdminConsoleService.instance.businessClaims();
      if (mounted) setState(() { _allowed = true; _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _allowed = true; _loading = false; _error = e.toString(); });
    }
  }

  void _preview(Map<String, dynamic> data) {
    final category = (data['category'] ?? 'cafe').toString();
    final venueId = (data['venueId'] ?? '').toString();
    final venueName = (data['venueName'] ?? data['legalName'] ?? 'İşletme').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessHubScreen(
          initialCategory: category,
          initialVenueId: venueId.isEmpty ? 'admin_preview' : venueId,
          initialVenueName: venueName,
          previewMode: true,
        ),
      ),
    );
  }

  void _details(Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          Text((data['venueName'] ?? data['legalName'] ?? 'İşletme').toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _Info('Durum', (data['status'] ?? '-').toString()),
          _Info('Kategori', (data['category'] ?? '-').toString()),
          _Info('E-posta', (data['businessEmail'] ?? '-').toString()),
          _Info('Telefon', (data['businessPhone'] ?? '-').toString()),
          _Info('Yetkili UID', (data['applicantUid'] ?? '-').toString()),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () { Navigator.pop(context); _preview(data); },
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('İşletme Panelini Önizle'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered => _items.where((d) {
    final status = (d['status'] ?? '').toString();
    if (_filter != 'all' && status != _filter) return false;
    if (_query.isEmpty) return true;
    final text = '${d['venueName'] ?? ''} ${d['legalName'] ?? ''} ${d['businessEmail'] ?? ''} ${d['category'] ?? ''}'.toLowerCase();
    return text.contains(_query);
  }).toList();

  @override
  Widget build(BuildContext context) {
    if (_allowed == false) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Yönetici yetkisi gerekli.')));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İşletme Kontrol Merkezi', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [IconButton(onPressed: _load, tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.cyan.withValues(alpha: .4))),
            child: const Row(children: [
              Icon(Icons.touch_app_rounded, color: AppColors.cyan),
              SizedBox(width: 10),
              Expanded(child: Text('İşletmeye dokununca sahibi gibi panel önizlemesi açılır. Bilgi simgesi kayıt detaylarını gösterir.', style: TextStyle(color: Colors.white70, height: 1.35))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: TextField(onChanged: (v) => setState(() => _query = v.trim().toLowerCase()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'İşletme ara')),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Tümü')),
                ButtonSegment(value: 'pending_review', label: Text('Bekleyen')),
                ButtonSegment(value: 'verified', label: Text('Onaylı')),
                ButtonSegment(value: 'rejected', label: Text('Red')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _preview({'category': 'cafe', 'venueId': 'admin_demo', 'venueName': 'TBT Demo İşletme'}),
        icon: const Icon(Icons.visibility_rounded),
        label: const Text('Demo Panel'),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: Colors.white54),
            const SizedBox(height: 12),
            const Text('İşletmeler yüklenemedi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Admin veri servisiyle bağlantı kurulamadı.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar Dene')),
          ]),
        ),
      );
    }
    final docs = _filtered;
    if (docs.isEmpty) return const Center(child: Text('Bu filtrede işletme yok.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final d = docs[index];
          final status = (d['status'] ?? '').toString();
          final name = (d['venueName'] ?? d['legalName'] ?? 'İşletme').toString();
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 7, 6, 7),
              leading: CircleAvatar(
                backgroundColor: status == 'verified' ? AppColors.cyan.withValues(alpha: .12) : AppColors.surfaceStrong,
                child: Icon(status == 'verified' ? Icons.verified_rounded : Icons.storefront_rounded, color: status == 'verified' ? AppColors.cyan : Colors.white70),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${d['category'] ?? 'işletme'} • ${status.isEmpty ? 'başvuru yok' : status}'),
              onTap: () => _preview(d),
              trailing: IconButton(tooltip: 'İşletme detayları', onPressed: () => _details(d), icon: const Icon(Icons.info_outline_rounded)),
            ),
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white54))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );
}
