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
        merged[doc.id] = {
          ...data,
          'venueKey': doc.id,
          'venueName': (data['venueName'] ?? data['name'] ?? 'İşletme').toString(),
          'status': data['verified'] == true ? 'verified' : 'registered',
          'source': 'venue',
        };
      }
      for (final raw in claims) {
        final claim = Map<String, dynamic>.from(raw);
        final key = _keyFor(claim);
        final existing = merged[key];
        merged[key] = existing == null
            ? {...claim, 'source': 'claim'}
            : {
                ...existing,
                ...claim,
                'venueKey': existing['venueKey'] ?? claim['venueKey'] ?? key,
                'venueName': claim['venueName'] ?? existing['venueName'],
                'source': 'venue+claim',
              };
      }
      final items = merged.values.toList()
        ..sort((a, b) => (a['venueName'] ?? a['legalName'] ?? '').toString().compareTo((b['venueName'] ?? b['legalName'] ?? '').toString()));
      if (mounted) setState(() { _allowed = true; _items = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _allowed = true; _loading = false; _error = error.toString(); });
    }
  }

  void _preview(Map<String, dynamic> data) {
    final category = (data['category'] ?? 'cafe').toString();
    final name = (data['venueName'] ?? data['legalName'] ?? 'TBT İşletme').toString();
    Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessPanelPreviewScreen(venueName: name, category: category)));
  }

  Future<void> _review(Map<String, dynamic> data, {required bool approve}) async {
    final key = _keyFor(data);
    if (_reviewing.contains(key)) return;
    var reason = '';
    if (!approve) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Başvuruyu reddet'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Red nedeni (başvuru sahibine gösterilir)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Reddet')),
          ],
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (confirmed != true) return;
      if (reason.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Red nedeni yazmalısın.')));
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('İşletmeyi onayla'),
          content: const Text('Başvuru sahibine bu işletmenin doğrulanmış yönetim yetkisi verilecek.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Onayla')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final category = (data['category'] ?? '').toString().trim();
    final venueId = (data['venueId'] ?? '').toString().trim();
    if (category.isEmpty || venueId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Başvurunun mekan kimliği eksik.')));
      return;
    }
    setState(() => _reviewing.add(key));
    try {
      await AdminConsoleService.instance.reviewBusinessClaim(
        category: category,
        venueId: venueId,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'İşletme onaylandı.' : 'Başvuru reddedildi.')));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $error')));
    } finally {
      if (mounted) setState(() => _reviewing.remove(key));
    }
  }

  List<Map<String, dynamic>> get _filtered => _items.where((data) {
    final status = (data['status'] ?? 'registered').toString();
    if (_filter != 'all' && status != _filter) return false;
    if (_query.isEmpty) return true;
    final haystack = '${data['venueName'] ?? ''} ${data['legalName'] ?? ''} ${data['businessEmail'] ?? data['ownerEmail'] ?? ''} ${data['category'] ?? ''} ${data['venueKey'] ?? ''}'.toLowerCase();
    return haystack.contains(_query);
  }).toList();

  int _count(String status) => status == 'all' ? _items.length : _items.where((item) => (item['status'] ?? 'registered').toString() == status).length;

  String _statusLabel(String status) => switch (status) {
    'verified' => 'Onaylı',
    'pending_review' => 'Bekleyen',
    'rejected' => 'Reddedildi',
    'registered' => 'Kayıtlı',
    _ => 'Kayıtlı',
  };

  String _categoryLabel(String category) => switch (category) {
    'cafe' => 'Kafe',
    'dining' => 'Lezzet',
    'hotel' => 'Otel',
    _ => 'İşletme',
  };

  @override
  Widget build(BuildContext context) {
    if (_allowed == false) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Yönetici yetkisi gerekli.')));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İşletmeler'),
        actions: [IconButton(onPressed: _load, tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            _summary(),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'İşletme adı, e-posta veya mekan kimliği ara'),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('all', 'Tümü', _count('all')),
                _chip('registered', 'Kayıtlı', _count('registered')),
                _chip('pending_review', 'Bekleyen', _count('pending_review')),
                _chip('verified', 'Onaylı', _count('verified')),
                _chip('rejected', 'Reddedilen', _count('rejected')),
              ]),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 70), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _errorCard()
            else if (_filtered.isEmpty)
              _empty()
            else
              ..._filtered.map(_businessCard),
          ],
        ),
      ),
    );
  }

  Widget _summary() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.storefront_rounded, color: AppColors.cyan), SizedBox(width: 10), Text('İşletme yönetimi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 7),
      const Text('Mekan profilleri ve işletme başvuruları aynı merkezde gösterilir.', style: TextStyle(color: Colors.white60, height: 1.35)),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _mini('Toplam', _count('all'))), const SizedBox(width: 8), Expanded(child: _mini('Bekleyen', _count('pending_review'))), const SizedBox(width: 8), Expanded(child: _mini('Onaylı', _count('verified')))]),
    ]),
  );

  Widget _mini(String label, int count) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(14)),
    child: Column(children: [Text('$count', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))]),
  );

  Widget _chip(String value, String label, int count) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(selected: _filter == value, onSelected: (_) => setState(() => _filter = value), label: Text('$label  $count')),
  );

  Widget _businessCard(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'registered').toString();
    final name = (data['venueName'] ?? data['legalName'] ?? 'İşletme').toString();
    final category = (data['category'] ?? '').toString();
    final email = (data['businessEmail'] ?? data['ownerEmail'] ?? '').toString();
    final verified = status == 'verified' || data['verified'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _details(data),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: verified ? AppColors.cyan.withValues(alpha: .12) : AppColors.surfaceStrong, child: Icon(verified ? Icons.verified_rounded : Icons.storefront_outlined, color: verified ? AppColors.cyan : Colors.white70)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 4),
              Text('${_categoryLabel(category)} • ${_statusLabel(status)}', style: const TextStyle(color: Colors.white60)),
              if (email.isNotEmpty) ...[const SizedBox(height: 3), Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12))],
            ])),
            if (status == 'pending_review') const Icon(Icons.fact_check_outlined, color: AppColors.cyan) else const Icon(Icons.info_outline_rounded, color: Colors.white54),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ]),
        ),
      ),
    );
  }

  void _details(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'registered').toString();
    final evidenceUrl = (data['evidenceUrl'] ?? '').toString().trim();
    final key = _keyFor(data);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final busy = _reviewing.contains(key);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .82,
            minChildSize: .5,
            maxChildSize: .96,
            builder: (_, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              children: [
                Text((data['venueName'] ?? data['legalName'] ?? 'İşletme').toString(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                _info('Durum', _statusLabel(status)),
                _info('Kategori', _categoryLabel((data['category'] ?? '').toString())),
                _info('E-posta', (data['businessEmail'] ?? data['ownerEmail'] ?? '-').toString()),
                _info('Telefon', (data['businessPhone'] ?? data['phone'] ?? '-').toString()),
                _info('Yasal ad', (data['legalName'] ?? '-').toString()),
                _info('Vergi dairesi', (data['taxOffice'] ?? '-').toString()),
                _info('Vergi no', data['taxNumberLast4'] == null ? '-' : '••••••${data['taxNumberLast4']}'),
                if (status == 'rejected' && (data['rejectionReason'] ?? '').toString().isNotEmpty)
                  _info('Red nedeni', data['rejectionReason'].toString()),
                const SizedBox(height: 18),
                const Text('Yetki kanıtı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                if (evidenceUrl.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(16)),
                    child: const Row(children: [Icon(Icons.image_not_supported_outlined, color: Colors.white54), SizedBox(width: 10), Expanded(child: Text('Bu başvuruda kanıt görseli bulunamadı.', style: TextStyle(color: Colors.white60)))]),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 220, maxHeight: 420),
                      color: AppColors.surfaceStrong,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Image.network(
                          evidenceUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) => progress == null ? child : const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
                          errorBuilder: (_, __, ___) => const SizedBox(height: 220, child: Center(child: Text('Kanıt görseli yüklenemedi.'))),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                if (status == 'pending_review')
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () async { setSheetState(() {}); await _review(data, approve: false); },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : () async { setSheetState(() {}); await _review(data, approve: true); },
                        icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.verified_rounded),
                        label: const Text('Onayla'),
                      ),
                    ),
                  ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () { Navigator.pop(sheetContext); _preview(data); },
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Paneli Görüntüle'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white54))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.only(top: 74),
    child: Column(children: [
      const Icon(Icons.storefront_outlined, size: 48, color: Colors.white24),
      const SizedBox(height: 12),
      Text(_query.isNotEmpty ? 'Aramana uygun işletme yok.' : 'Bu filtrede işletme yok.', style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _errorCard() => Padding(
    padding: const EdgeInsets.only(top: 50),
    child: Column(children: [
      const Icon(Icons.cloud_off_rounded, size: 46, color: Colors.white38),
      const SizedBox(height: 10),
      const Text('İşletmeler yüklenemedi', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      if (_error != null) Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar Dene')),
    ]),
  );
}
