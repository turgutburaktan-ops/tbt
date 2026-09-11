import 'package:flutter/material.dart';

import '../services/admin_access.dart';
import '../services/business_service.dart';
import '../theme/app_theme.dart';

class AdminBusinessPerformanceScreen extends StatefulWidget {
  final String venueKey;
  final String venueName;
  final String category;
  final bool premiumActive;
  final DateTime? premiumUntil;

  const AdminBusinessPerformanceScreen({
    super.key,
    required this.venueKey,
    required this.venueName,
    required this.category,
    required this.premiumActive,
    this.premiumUntil,
  });

  @override
  State<AdminBusinessPerformanceScreen> createState() =>
      _AdminBusinessPerformanceScreenState();
}

class _AdminBusinessPerformanceScreenState
    extends State<AdminBusinessPerformanceScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      if (!await AdminAccess.currentUserIsAuthorized()) {
        throw Exception('Yönetici yetkisi gerekli.');
      }
      final result = await BusinessService.instance.authenticatedCall(
        'getBusinessDashboard',
        {'venueKey': widget.venueKey},
      );
      if (mounted) setState(() => _data = result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _number(Object? value) => (value as num?)?.toInt() ?? 0;

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  @override
  Widget build(BuildContext context) {
    final metrics = Map<String, dynamic>.from((_data['metrics'] as Map?) ?? const {});
    final daily = ((_data['daily'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final reservations = ((_data['reservations'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final boost = _data['boost'] is Map
        ? Map<String, dynamic>.from(_data['boost'] as Map)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İşletme Performansı'),
        actions: [IconButton(onPressed: _load, tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, retry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 34),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10262B), Color(0xFF181426), Color(0xFF111217)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.cyan.withValues(alpha: .35)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)),
                              child: const Icon(Icons.storefront_rounded, color: AppColors.cyan),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(widget.venueName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(widget.category, style: const TextStyle(color: Colors.white60)),
                            ])),
                            _StatusPill(active: widget.premiumActive),
                          ]),
                          const SizedBox(height: 13),
                          Text(
                            widget.premiumActive
                                ? 'TBT Business Premium aktif${widget.premiumUntil == null ? '' : ' • ${_date(widget.premiumUntil!)} tarihine kadar'}'
                                : 'TBT Business • Premium aktif değil',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          const Text('İşletme sahibinin gördüğü performans verilerinin salt okunur yönetici görünümü.', style: TextStyle(color: Colors.white54, height: 1.35)),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      const _SectionTitle('Genel performans'),
                      const SizedBox(height: 9),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        childAspectRatio: 1.65,
                        children: [
                          _MetricCard('Takipçi', _number(_data['followers']), Icons.people_alt_outlined),
                          _MetricCard('Profil', _number(metrics['profile_view']), Icons.visibility_outlined),
                          _MetricCard('Menü', _number(metrics['menu_view']), Icons.restaurant_menu_rounded),
                          _MetricCard('Kampanya', _number(metrics['campaign_view']), Icons.local_offer_outlined),
                          _MetricCard('Etkinlik', _number(metrics['event_view']), Icons.event_outlined),
                          _MetricCard('Rezervasyon', _number(metrics['reservation_open']), Icons.event_seat_outlined),
                          _MetricCard('Telefon', _number(metrics['phone']), Icons.phone_outlined),
                          _MetricCard('Yol tarifi', _number(metrics['directions']), Icons.directions_outlined),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _DailyPerformance(days: daily),
                      const SizedBox(height: 18),
                      _BoostPerformance(boost: boost, premiumActive: widget.premiumActive),
                      const SizedBox(height: 18),
                      _ReservationSummary(items: reservations),
                    ],
                  ),
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900));
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _MetricCard(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(icon, color: AppColors.cyan, size: 21),
      const SizedBox(width: 10),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ])),
    ]),
  );
}

class _DailyPerformance extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _DailyPerformance({required this.days});
  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<int>(1, (max, day) {
      final value = (day['total'] as num?)?.toInt() ?? 0;
      return value > max ? value : max;
    });
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('Son 7 gün'),
        const SizedBox(height: 4),
        const Text('Tüm müşteri etkileşimleri', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 16),
        if (days.isEmpty)
          const Text('Henüz günlük performans verisi oluşmadı.', style: TextStyle(color: Colors.white60))
        else
          SizedBox(height: 116, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: days.reversed.map((day) {
            final value = (day['total'] as num?)?.toInt() ?? 0;
            final label = (day['date'] ?? '').toString();
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('$value', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Container(height: 12 + 60 * value / maxValue, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.cyan, Color(0xFF7456E8)], begin: Alignment.bottomCenter, end: Alignment.topCenter), borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 5),
                Text(label.length >= 10 ? label.substring(8, 10) : label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ]),
            ));
          }).toList())),
      ]),
    ));
  }
}

class _BoostPerformance extends StatelessWidget {
  final Map<String, dynamic>? boost;
  final bool premiumActive;
  const _BoostPerformance({required this.boost, required this.premiumActive});
  @override
  Widget build(BuildContext context) {
    final impressions = (boost?['impressions'] as num?)?.toInt() ?? 0;
    final clicks = (boost?['clicks'] as num?)?.toInt() ?? 0;
    final rate = impressions == 0 ? 0.0 : clicks * 100 / impressions;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.rocket_launch_outlined, color: AppColors.cyan), SizedBox(width: 9), _SectionTitle('Business Boost')]),
        const SizedBox(height: 10),
        Text(boost == null ? (premiumActive ? 'Aktif Boost bulunmuyor.' : 'Boost için Business Premium gerekir.') : 'Aktif Boost performansı', style: const TextStyle(color: Colors.white60)),
        if (boost != null) ...[
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: _MiniStat('Gösterim', '$impressions')),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Tıklama', '$clicks')),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Oran', '${rate.toStringAsFixed(1)}%')),
          ]),
        ],
      ]),
    ));
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))]),
  );
}

class _ReservationSummary extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ReservationSummary({required this.items});
  @override
  Widget build(BuildContext context) {
    int count(String status) => items.where((item) => (item['status'] ?? 'pending') == status).length;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('Rezervasyon özeti'),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: _MiniStat('Bekleyen', '${count('pending')}')),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat('Onaylanan', '${count('accepted')}')),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat('Reddedilen', '${count('rejected')}')),
        ]),
      ]),
    ));
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: (active ? const Color(0xFFFFC857) : Colors.white).withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
    child: Text(active ? 'PREMIUM' : 'BUSINESS', style: TextStyle(color: active ? const Color(0xFFFFC857) : Colors.white60, fontSize: 10, fontWeight: FontWeight.w900)),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const _ErrorState({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 44, color: Colors.white54),
      const SizedBox(height: 10),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      FilledButton(onPressed: retry, child: const Text('Tekrar dene')),
    ]),
  ));
}
