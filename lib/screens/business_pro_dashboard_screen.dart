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
  String? _loadWarning;
  String get _venueKey =>
      BusinessService.instance.venueKey(widget.category, widget.venueId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    Map<String, dynamic> entitlement = const {};
    Map<String, dynamic> dashboard = const {};
    final warnings = <String>[];
    try {
      entitlement = await BusinessService.instance.entitlementStatus(
        widget.category,
        widget.venueId,
      );
    } catch (e) {
      warnings.add('Paket bilgisi yenilenemedi.');
    }
    if (entitlement.isEmpty || entitlement['entitled'] == true) {
      try {
        dashboard = await BusinessService.instance.authenticatedCall(
          'getBusinessDashboard',
          {'venueKey': _venueKey},
        );
      } catch (e) {
        warnings.add('Bazı istatistikler şu anda alınamadı.');
      }
    }
    if (mounted) {
      setState(() {
        _entitlement = entitlement;
        _dashboard = dashboard;
        _loadWarning = warnings.isEmpty ? null : warnings.join(' ');
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  String _error(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _boost() async {
    try {
      final data = await BusinessService.instance.authenticatedCall(
        'createBusinessBoost',
        {
          'venueKey': _venueKey,
          'targetType': 'profile',
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
          const SnackBar(content: Text('3 aylık ücretsiz Premium erişimin başladı.')),
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
    final entitled = _entitlement['entitled'] == true || _dashboard.isNotEmpty;
    final premium = _entitlement['premiumEntitled'] == true;
    final trialUsed = _entitlement['premiumTrialUsed'] == true;
    final trialUntilMs = (_entitlement['premiumTrialUntilMs'] as num?)?.toInt() ?? 0;
    final boost = _dashboard['boost'] is Map
        ? Map<String, dynamic>.from(_dashboard['boost'] as Map)
        : null;

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
                  if (_loadWarning != null) ...[
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFC857),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x66FFC857)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFFFC857)),
                        const SizedBox(width: 9),
                        Expanded(child: Text(_loadWarning!, style: const TextStyle(height: 1.35))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                        if (premium && trialUntilMs > 0) ...[
                          const SizedBox(height: 9),
                          Text(
                            'Ücretsiz Premium bitişi: ${_date(trialUntilMs)}',
                            style: const TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.w800),
                          ),
                        ],
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
                                  label: Text(trialUsed ? '3 aylık erişim kullanıldı' : '3 ay ücretsiz Premium'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!premium) const SizedBox(height: 10),
                    _BoostCard(boost: boost, premium: premium, onStart: _boost),
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
  String _date(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
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

class _BoostCard extends StatelessWidget {
  final Map<String, dynamic>? boost;
  final bool premium;
  final VoidCallback onStart;
  const _BoostCard({required this.boost, required this.premium, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final active = boost != null && boost!['status'] == 'active';
    final impressions = (boost?['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (boost?['clicks'] as num?)?.toInt() ?? 0;
    final endsAtMs = (boost?['endsAtMs'] as num?)?.toInt() ?? 0;
    final clickRate = impressions == 0 ? 0 : (clicks * 100 / impressions);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.rocket_launch_outlined, color: AppColors.cyan),
              SizedBox(width: 9),
              Text('Business Boost', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            Text(
              !premium
                  ? 'Boost, yalnızca Premium işletmelerin şehir ve kategori sonuçlarında öne çıkmasını sağlar.'
                  : active
                      ? 'Profil görünürlüğü Boost ile artırılıyor.'
                      : 'İşletmeni 3 gün boyunca şehir ve kategori sonuçlarında öne çıkar.',
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
            if (active) ...[
              const SizedBox(height: 13),
              Row(children: [
                Expanded(child: _BoostStat(label: 'Gösterim', value: '$impressions')),
                const SizedBox(width: 8),
                Expanded(child: _BoostStat(label: 'Tıklama', value: '$clicks')),
                const SizedBox(width: 8),
                Expanded(child: _BoostStat(label: 'Oran', value: '${clickRate.toStringAsFixed(1)}%')),
              ]),
              if (endsAtMs > 0) ...[
                const SizedBox(height: 10),
                Text('Bitiş: ${_formatDate(endsAtMs)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: premium ? onStart : null,
                  icon: Icon(premium ? Icons.bolt_rounded : Icons.lock_outline_rounded),
                  label: Text(premium ? '3 Günlük Boost Başlat' : 'Premium Gerekli'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _BoostStat extends StatelessWidget {
  final String label;
  final String value;
  const _BoostStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );
}
