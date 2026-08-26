import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_console_service.dart';
import '../theme/app_theme.dart';
import 'business_panel_preview_screen.dart';

class AdminBusinessesV2Screen extends StatefulWidget {
  const AdminBusinessesV2Screen({super.key});

  @override
  State<AdminBusinessesV2Screen> createState() =>
      _AdminBusinessesV2ScreenState();
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

  String _keyFor(Map<String, dynamic> data) {
    final direct = (data['venueKey'] ?? data['id'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final category = (data['category'] ?? '').toString().trim();
    final venueId = (data['venueId'] ?? '').toString().trim();
    if (category.isNotEmpty && venueId.isNotEmpty) return '$category:$venueId';
    return '${data['venueName'] ?? data['legalName'] ?? ''}|$category'
        .toLowerCase();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      if (token?.claims?['admin'] != true) {
        if (mounted) {
          setState(() {
            _allowed = false;
            _loading = false;
          });
        }
        return;
      }

      final claimsFuture = AdminConsoleService.instance.businessClaims();
      final venuesFuture = FirebaseFirestore.instance
          .collection('business_venues')
          .limit(1000)
          .get();
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
        if (existing == null) {
          merged[key] = {...claim, 'source': 'claim'};
        } else {
          merged[key] = {
            ...existing,
            ...claim,
            'venueKey': existing['venueKey'] ?? claim['venueKey'] ?? key,
            'venueName': claim['venueName'] ?? existing['venueName'],
            'source': 'venue+claim',
          };
        }
      }

      final items = merged.values.toList()
        ..sort((a, b) =>
            (a['venueName'] ?? a['legalName'] ?? '').toString().compareTo(
                  (b['venueName'] ?? b['legalName'] ?? '').toString(),
                ));

      if (mounted) {
        setState(() {
          _allowed = true;
          _items = items;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _allowed = true;
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  void _preview(Map<String, dynamic> data) {
    final category = (data['category'] ?? 'cafe').toString();
    final name = (data['venueName'] ?? data['legalName'] ?? 'TBT İşletme')
        .toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessPanelPreviewScreen(
          venueName: name,
          category: category,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered => _items.where((data) {
        final status = (data['status'] ?? 'registered').toString();
        if (_filter != 'all' && status != _filter) return false;
        if (_query.isEmpty) return true;
        final haystack =
            '${data['venueName'] ?? ''} ${data['legalName'] ?? ''} ${data['businessEmail'] ?? data['ownerEmail'] ?? ''} ${data['category'] ?? ''} ${data['venueKey'] ?? ''}'
                .toLowerCase();
        return haystack.contains(_query);
      }).toList();

  int _count(String status) => status == 'all'
      ? _items.length
      : _items
          .where((item) => (item['status'] ?? 'registered').toString() == status)
          .length;

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
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Yönetici yetkisi gerekli.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İşletmeler'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            _summary(),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'İşletme adı, e-posta veya mekan kimliği ara',
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('all', 'Tümü', _count('all')),
                  _chip('registered', 'Kayıtlı', _count('registered')),
                  _chip('pending_review', 'Bekleyen', _count('pending_review')),
                  _chip('verified', 'Onaylı', _count('verified')),
                  _chip('rejected', 'Reddedilen', _count('rejected')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 70),
                child: Center(child: CircularProgressIndicator()),
              )
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storefront_rounded, color: AppColors.cyan),
                SizedBox(width: 10),
                Text(
                  'İşletme yönetimi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Mekan profilleri ve işletme başvuruları aynı merkezde gösterilir.',
              style: TextStyle(color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _mini('Toplam', _count('all'))),
                const SizedBox(width: 8),
                Expanded(child: _mini('Bekleyen', _count('pending_review'))),
                const SizedBox(width: 8),
                Expanded(child: _mini('Onaylı', _count('verified'))),
              ],
            ),
          ],
        ),
      );

  Widget _mini(String label, int count) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceStrong,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _chip(String value, String label, int count) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
          label: Text('$label  $count'),
        ),
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
        onTap: () => _preview(data),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: verified
                    ? AppColors.cyan.withValues(alpha: .12)
                    : AppColors.surfaceStrong,
                child: Icon(
                  verified ? Icons.verified_rounded : Icons.storefront_outlined,
                  color: verified ? AppColors.cyan : Colors.white70,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_categoryLabel(category)} • ${_statusLabel(status)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Detay',
                onPressed: () => _details(data),
                icon: const Icon(Icons.info_outline_rounded),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _details(Map<String, dynamic> data) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (data['venueName'] ?? data['legalName'] ?? 'İşletme').toString(),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _info('Durum', _statusLabel((data['status'] ?? 'registered').toString())),
            _info('Kategori', _categoryLabel((data['category'] ?? '').toString())),
            _info(
              'E-posta',
              (data['businessEmail'] ?? data['ownerEmail'] ?? '-').toString(),
            ),
            _info('Telefon', (data['businessPhone'] ?? data['phone'] ?? '-').toString()),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _preview(data);
              },
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Paneli Görüntüle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(color: Colors.white54)),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 74),
        child: Column(
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty
                  ? 'Aramana uygun işletme yok.'
                  : 'Bu filtrede işletme yok.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );

  Widget _errorCard() => Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 46, color: Colors.white38),
            const SizedBox(height: 10),
            const Text(
              'İşletmeler yüklenemedi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            if (_error != null)
              Text(
                _error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
}
