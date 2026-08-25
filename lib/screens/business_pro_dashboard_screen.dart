import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/business_service.dart';
import '../theme/app_theme.dart';

class BusinessProDashboardScreen extends StatefulWidget {
  final String category;
  final String venueId;
  final String venueName;

  const BusinessProDashboardScreen({
    super.key,
    required this.category,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<BusinessProDashboardScreen> createState() => _BusinessProDashboardScreenState();
}

class _BusinessProDashboardScreenState extends State<BusinessProDashboardScreen> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  bool _loading = true;
  Map<String, dynamic> _entitlement = const {};
  Map<String, dynamic> _dashboard = const {};

  String get _venueKey => BusinessService.instance.venueKey(widget.category, widget.venueId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entitlement = await BusinessService.instance.entitlementStatus(widget.category, widget.venueId);
      final dashboardResult = await _functions.httpsCallable('getBusinessDashboard').call({'venueKey': _venueKey});
      if (!mounted) return;
      setState(() {
        _entitlement = entitlement;
        _dashboard = Map<String, dynamic>.from(dashboardResult.data as Map);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _error(Object e) {
    if (e is FirebaseFunctionsException) return e.message ?? 'İşlem tamamlanamadı.';
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _boost() async {
    try {
      final result = await _functions.httpsCallable('createBusinessBoost').call({
        'venueKey': _venueKey,
        'targetType': 'business_profile',
        'targetId': _venueKey,
        'days': 3,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['status'] == 'trial' ? '3 günlük ücretsiz Boost başlatıldı.' : 'Boost başlatıldı.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  Future<void> _respondReservation(String id, String decision) async {
    try {
      await _functions.httpsCallable('respondBusinessReservation').call({
        'venueKey': _venueKey,
        'reservationId': id,
        'decision': decision,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Map<String, dynamic>.from((_dashboard['metrics'] as Map?) ?? const {});
    final followers = (_dashboard['followers'] as num?)?.toInt() ?? 0;
    final early = _entitlement['earlyAccessActive'] == true;
    final entitled = _entitlement['entitled'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('TBT Business Pro')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cyan),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.workspace_premium_rounded, color: AppColors.cyan),
                        const SizedBox(width: 8),
                        Expanded(child: Text(early ? 'Kurucu İşletme • Pro Ücretsiz' : entitled ? 'TBT Business Pro' : 'TBT Business', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        early
                            ? 'Erken katılım avantajın aktif. Pro araçlarını lansman döneminde ücretsiz kullanabilirsin.'
                            : entitled
                                ? 'Gelişmiş işletme araçların aktif.'
                                : 'Temel işletme hesabın aktif.',
                        style: const TextStyle(color: Colors.white60, height: 1.4),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  const Text('Performans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Metric(label: 'Takipçi', value: followers),
                      _Metric(label: 'Profil', value: _n(metrics['profile_view'])),
                      _Metric(label: 'Yol Tarifi', value: _n(metrics['directions'])),
                      _Metric(label: 'Telefon', value: _n(metrics['phone'])),
                      _Metric(label: 'Menü', value: _n(metrics['menu_view'])),
                      _Metric(label: 'Kampanya', value: _n(metrics['campaign_view'])),
                      _Metric(label: 'Etkinlik', value: _n(metrics['event_view'])),
                      _Metric(label: 'Rezervasyon', value: _n(metrics['reservation_open'])),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.rocket_launch_outlined, color: AppColors.cyan),
                      title: const Text('Business Boost', style: TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: const Text('Lansman döneminde işletmeni 3 gün ücretsiz öne çıkar. Sonradan ücretli görünürlük servisine dönüşebilir.'),
                      trailing: FilledButton(onPressed: _boost, child: const Text('Boost')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Rezervasyon Talepleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('business_venues').doc(_venueKey).collection('reservations').orderBy('createdAt', descending: true).limit(30).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Card(child: ListTile(title: Text('Rezervasyonlar yüklenemedi.')));
                      if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()));
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Card(child: ListTile(title: Text('Henüz rezervasyon talebi yok.')));
                      return Column(children: docs.map((doc) {
                        final d = doc.data();
                        final status = (d['status'] ?? 'pending').toString();
                        final at = (d['at'] as Timestamp?)?.toDate();
                        final people = (d['partySize'] as num?)?.toInt() ?? 0;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.event_seat_outlined),
                            title: Text('$people kişi${at == null ? '' : ' • ${at.day}.${at.month}.${at.year} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'}'),
                            subtitle: Text((d['note'] ?? '').toString().isEmpty ? _statusText(status) : '${_statusText(status)}\n${d['note']}'),
                            trailing: status == 'pending'
                                ? Wrap(spacing: 4, children: [
                                    IconButton(onPressed: () => _respondReservation(doc.id, 'rejected'), icon: const Icon(Icons.close_rounded)),
                                    IconButton(onPressed: () => _respondReservation(doc.id, 'accepted'), icon: const Icon(Icons.check_rounded, color: AppColors.cyan)),
                                  ])
                                : null,
                          ),
                        );
                      }).toList());
                    },
                  ),
                ],
              ),
            ),
    );
  }

  int _n(dynamic value) => (value as num?)?.toInt() ?? 0;
  String _statusText(String value) => switch (value) {
        'accepted' => 'Onaylandı',
        'rejected' => 'Reddedildi',
        _ => 'Yanıt bekliyor',
      };
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        width: (MediaQuery.sizeOf(context).width - 42) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );
}
