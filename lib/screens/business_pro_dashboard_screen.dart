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
  State<BusinessProDashboardScreen> createState() =>
      _BusinessProDashboardScreenState();
}

class _BusinessProDashboardScreenState
    extends State<BusinessProDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic> _entitlement = const {}, _dashboard = const {};
  String get _venueKey =>
      BusinessService.instance.venueKey(widget.category, widget.venueId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final entitlement = await BusinessService.instance.entitlementStatus(
        widget.category,
        widget.venueId,
      );
      final entitled = entitlement['entitled'] == true;
      Map<String, dynamic> dashboard = const {};
      if (entitled) {
        dashboard = await BusinessService.instance.authenticatedCall(
          'getBusinessDashboard',
          {'venueKey': _venueKey},
        );
      }
      if (!mounted) return;
      setState(() {
        _entitlement = entitlement;
        _dashboard = dashboard;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _error(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _boost() async {
    try {
      final data = await BusinessService.instance.authenticatedCall(
        'createBusinessBoost',
        {
          'venueKey': _venueKey,
          'targetType': 'business_profile',
          'targetId': _venueKey,
          'days': 3,
        },
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['status'] == 'trial'
                  ? '3 günlük ücretsiz Boost başlatıldı.'
                  : 'Boost başlatıldı.',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  Future<void> _startPremiumTrial() async {
    try {
      await BusinessService.instance.startPremiumTrial(
        widget.category,
        widget.venueId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('30 günlük Premium denemen başladı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(e))));
      }
    }
  }

  Future<void> _respondReservation(String id, String decision) async {
    try {
      await BusinessService.instance.authenticatedCall('respondBusinessReservation', {
        'venueKey': _venueKey,
        'reservationId': id,
        'decision': decision,
      });
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Map<String, dynamic>.from(
      (_dashboard['metrics'] as Map?) ?? const {},
    );
    final followers = (_dashboard['followers'] as num?)?.toInt() ?? 0;
    final reservations = ((_dashboard['reservations'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final entitled = _entitlement['entitled'] == true;
    final premium = _entitlement['premiumEntitled'] == true;
    final trialUsed = _entitlement['premiumTrialUsed'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('TBT Business Pro')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: entitled ? AppColors.cyan : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              entitled
                                  ? Icons.workspace_premium_rounded
                                  : Icons.lock_outline_rounded,
                              color: entitled ? AppColors.cyan : Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                premium
                                    ? 'TBT Business Premium'
                                    : entitled
                                        ? 'TBT Business Pro • Ücretsiz'
                                        : 'TBT Business',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          premium
                              ? 'Premium görünürlük, Boost ve gelişmiş büyüme ayrıcalıkların aktif.'
                              : entitled
                                  ? 'İstatistik, rezervasyon, menü, kampanya ve içerik araçlarının tamamı ücretsiz Pro planında aktif.'
                                  : 'İşletme araçları doğrulama sonrasında açılır.',
                          style: const TextStyle(
                            color: Colors.white60,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!entitled) ...[
                    const SizedBox(height: 14),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white54,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Gelişmiş istatistikler, rezervasyon yönetimi ve Business Boost Pro araçlarıdır. Premium tekrar etkinleştirildiğinde mevcut verilerin kaybolmadan yeniden açılır.',
                                style: TextStyle(
                                  color: Colors.white60,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Performans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Metric(label: 'Takipçi', value: followers),
                        _Metric(
                          label: 'Profil',
                          value: _n(metrics['profile_view']),
                        ),
                        _Metric(
                          label: 'Yol Tarifi',
                          value: _n(metrics['directions']),
                        ),
                        _Metric(label: 'Telefon', value: _n(metrics['phone'])),
                        _Metric(label: 'Menü', value: _n(metrics['menu_view'])),
                        _Metric(
                          label: 'Kampanya',
                          value: _n(metrics['campaign_view']),
                        ),
                        _Metric(
                          label: 'Etkinlik',
                          value: _n(metrics['event_view']),
                        ),
                        _Metric(
                          label: 'Rezervasyon',
                          value: _n(metrics['reservation_open']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (!premium)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.diamond_outlined, color: Color(0xFFFFC857)),
                                  SizedBox(width: 9),
                                  Text('Business Premium', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              const SizedBox(height: 9),
                              const Text(
                                'Haritada ve aramada Boost, kampanya hedefleme, şube analizi, özel işletme rozeti, gelişmiş raporlar ve öncelikli destek.',
                                style: TextStyle(color: Colors.white60, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: trialUsed ? null : _startPremiumTrial,
                                  icon: const Icon(Icons.bolt_rounded),
                                  label: Text(trialUsed ? 'Deneme hakkı kullanıldı' : '30 gün ücretsiz dene'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!premium) const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.rocket_launch_outlined,
                          color: AppColors.cyan,
                        ),
                        title: const Text(
                          'Business Boost',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(premium
                            ? 'İşletmeni 3 gün boyunca ilgili kullanıcılara öne çıkar.'
                            : 'Boost, Premium görünürlük ayrıcalığıdır.'),
                        trailing: FilledButton(
                          onPressed: premium ? _boost : null,
                          child: const Text('Boost'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Rezervasyon Talepleri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (reservations.isEmpty)
                      const Card(
                        child: ListTile(
                          title: Text('Henüz rezervasyon talebi yok.'),
                        ),
                      )
                    else
                      ...reservations.map((d) {
                        final status = (d['status'] ?? 'pending').toString();
                        final atMs = (d['atMs'] as num?)?.toInt() ?? 0;
                        final at = atMs > 0
                            ? DateTime.fromMillisecondsSinceEpoch(atMs)
                            : null;
                        final people = (d['partySize'] as num?)?.toInt() ?? 0;
                        final note = (d['note'] ?? '').toString();
                        final id = (d['id'] ?? '').toString();
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.event_seat_outlined),
                            title: Text(
                              '$people kişi${at == null ? '' : ' • ${at.day}.${at.month}.${at.year} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'}',
                            ),
                            subtitle: Text(
                              note.isEmpty
                                  ? _statusText(status)
                                  : '${_statusText(status)}\n$note',
                            ),
                            trailing: status == 'pending'
                                ? Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _respondReservation(id, 'rejected'),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _respondReservation(id, 'accepted'),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          color: AppColors.cyan,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      }),
                  ],
                ],
              ),
            ),
    );
  }

  int _n(dynamic v) => (v as num?)?.toInt() ?? 0;
  String _statusText(String v) => switch (v) {
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
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    ),
  );
}
