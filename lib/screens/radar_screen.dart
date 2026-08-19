import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/turkey_selection_data.dart';
import '../models/photo_spot.dart';
import '../models/social_event.dart';
import '../services/activity_demand_service.dart';
import '../services/social_event_service.dart';
import '../services/spot_repository.dart';
import '../widgets/searchable_selection_field.dart';
import '../widgets/spot_image.dart';
import 'activity_demand_screen.dart';
import 'event_deep_link_screen.dart';
import 'route_planner_screen.dart';
import 'spot_detail_screen.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  static const _background = Color(0xFF090A0C);
  static const _surface = Color(0xFF121416);
  static const _surfaceAlt = Color(0xFF191C20);
  static const _border = Color(0xFF292D32);
  static const _accent = Color(0xFFB7BCC2);
  static const _cityPrefKey = 'radar_city';

  final _cityController = TextEditingController();
  String _period = 'now';
  List<PhotoSpot> _spots = const [];
  bool _loadingSpots = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString(_cityPrefKey)?.trim() ?? '';
      final spots = await SpotRepository.instance.loadSpots();
      if (!mounted) return;
      setState(() {
        _cityController.text = savedCity;
        _spots = spots;
        _loadingSpots = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSpots = false);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  bool _sameCity(String value) {
    final city = _cityController.text.trim();
    if (city.isEmpty) return true;
    return _normalize(value) == _normalize(city);
  }

  Future<void> _setCity(String value) async {
    final city = value.trim();
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityPrefKey, city);
  }

  bool _eventInPeriod(SocialEvent event) {
    final now = DateTime.now();
    final start = event.startsAt.toLocal();
    if (_period == 'now') {
      return start.isBefore(now.add(const Duration(hours: 6))) &&
          start.isAfter(now.subtract(const Duration(minutes: 30)));
    }
    if (_period == 'today') {
      return start.year == now.year &&
          start.month == now.month &&
          start.day == now.day;
    }
    return start.isBefore(now.add(const Duration(days: 7)));
  }

  bool _demandInPeriod(ActivityDemand demand) {
    if (_period == 'now') return demand.window == 'today';
    if (_period == 'today') {
      return demand.window == 'today' || demand.window == 'tomorrow';
    }
    return true;
  }

  List<PhotoSpot> get _visibleSpots {
    final result = _spots.where((spot) => _sameCity(spot.city)).toList();
    result.sort((a, b) => b.rating.compareTo(a.rating));
    return result.take(5).toList();
  }

  String _eventTime(SocialEvent event) {
    final now = DateTime.now();
    final d = event.startsAt.toLocal();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'Bugün • $time';
    if (isTomorrow) return 'Yarın • $time';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} • $time';
  }

  String _windowLabel(String window) => switch (window) {
        'tomorrow' => 'Yarın',
        'weekend' => 'Hafta sonu',
        _ => 'Bugün',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: StreamBuilder<List<ActivityDemand>>(
          stream: ActivityDemandService.instance.watchActive(),
          builder: (context, demandSnapshot) {
            final demands = (demandSnapshot.data ?? const <ActivityDemand>[])
                .where((d) => _sameCity(d.city) && _demandInPeriod(d))
                .toList();
            return StreamBuilder<List<SocialEvent>>(
              stream: SocialEventService.instance.watchUpcoming(),
              builder: (context, eventSnapshot) {
                final events = (eventSnapshot.data ?? const <SocialEvent>[])
                    .where((e) => _sameCity(e.city) && _eventInPeriod(e))
                    .toList();
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      _summaryCard(demands, events),
                      const SizedBox(height: 22),
                      _sectionTitle(
                        'Şu an hareketli',
                        'İnsanların yapmak istediği şeyler',
                        Icons.bolt_rounded,
                      ),
                      const SizedBox(height: 10),
                      _demandSection(demands),
                      const SizedBox(height: 24),
                      _sectionTitle(
                        'Yaklaşan etkinlikler',
                        'Katılabileceğin planlar',
                        Icons.event_available_outlined,
                      ),
                      const SizedBox(height: 10),
                      _eventSection(events.where((e) => (e.communityName ?? '').trim().isEmpty).toList()),
                      const SizedBox(height: 24),
                      _sectionTitle(
                        'Kampüs & topluluk',
                        'Toplulukların düzenlediği hareketler',
                        Icons.school_outlined,
                      ),
                      const SizedBox(height: 10),
                      _communityEventSection(events.where((e) => (e.communityName ?? '').trim().isNotEmpty).toList()),
                      const SizedBox(height: 24),
                      _sectionTitle(
                        'Çekim fırsatları',
                        _cityController.text.trim().isEmpty
                            ? 'Türkiye genelinden güçlü noktalar'
                            : '${_cityController.text.trim()} için güçlü noktalar',
                        Icons.photo_camera_outlined,
                      ),
                      const SizedBox(height: 10),
                      _spotSection(),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Radar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text('Çevrende ne oluyor?', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Bildirimler',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SearchableSelectionField(
          controller: _cityController,
          options: turkeyCities,
          labelText: 'Şehir',
          hintText: 'Şehir seç veya Türkiye geneli bırak',
          prefixIcon: Icons.location_city_outlined,
          onChanged: (value) => _setCity(value),
          onSelected: (value) => _setCity(value),
          maxSuggestions: 7,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(child: _periodButton('Şimdi', 'now')),
              Expanded(child: _periodButton('Bugün', 'today')),
              Expanded(child: _periodButton('Bu Hafta', 'week')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodButton(String label, String value) {
    final selected = _period == value;
    return Material(
      color: selected ? const Color(0xFF34383D) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => setState(() => _period = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(List<ActivityDemand> demands, List<SocialEvent> events) {
    final people = demands.map((d) => d.userId).toSet().length;
    final spots = _visibleSpots.length;
    final score = people + events.length * 2 + spots;
    final title = score >= 20
        ? 'Çevrende hareket var 🔥'
        : score >= 8
            ? 'Radar hareketleniyor'
            : 'Radar sakin';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(
            _cityController.text.trim().isEmpty
                ? 'Türkiye genelindeki güncel hareketleri gösteriyoruz.'
                : '${_cityController.text.trim()} için güncel hareketleri gösteriyoruz.',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric(Icons.groups_2_outlined, '$people kişi aktivite arıyor'),
              _metric(Icons.event_outlined, '${events.length} etkinlik'),
              _metric(Icons.photo_camera_outlined, '$spots çekim fırsatı'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _accent),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _sectionTitle(String title, String subtitle, IconData icon) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: _surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white45, fontSize: 11)),
              ],
            ),
          ),
        ],
      );

  Widget _demandSection(List<ActivityDemand> demands) {
    if (demands.isEmpty) {
      return _emptyCard('Bu filtrede henüz aktivite talebi yok.', Icons.bolt_outlined);
    }
    final grouped = <String, List<ActivityDemand>>{};
    for (final demand in demands) {
      final key = '${demand.activity}|${demand.city}|${demand.window}';
      grouped.putIfAbsent(key, () => []).add(demand);
    }
    final groups = grouped.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return Column(
      children: groups.take(4).map((items) {
        final first = items.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityDemandScreen(
                    initialActivity: first.activity,
                    initialCity: first.city,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _surfaceAlt,
                      child: Text('${items.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(first.activity, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(
                            '${first.city} • ${_windowLabel(first.window)} • ${items.length} kişi',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _eventSection(List<SocialEvent> events) {
    if (events.isEmpty) {
      return _emptyCard('Bu filtrede yaklaşan etkinlik görünmüyor.', Icons.event_busy_outlined);
    }
    return Column(children: events.take(4).map(_eventCard).toList());
  }

  Widget _communityEventSection(List<SocialEvent> events) {
    if (events.isEmpty) {
      return _emptyCard('Topluluk etkinlikleri burada görünecek.', Icons.school_outlined);
    }
    return Column(children: events.take(3).map(_eventCard).toList());
  }

  Widget _eventCard(SocialEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: event.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: _surfaceAlt, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.event_available_outlined, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('${_eventTime(event)} • ${event.city.isEmpty ? 'Konum detayda' : event.city}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${event.participantCount}/${event.capacity} kişi${(event.communityName ?? '').trim().isEmpty ? '' : ' • ${event.communityName}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white45, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _spotSection() {
    if (_loadingSpots) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final spots = _visibleSpots;
    if (spots.isEmpty) {
      return _emptyCard('Bu şehir için uygun çekim noktası bulunamadı.', Icons.photo_camera_back_outlined);
    }
    return Column(
      children: spots.map((spot) {
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              SpotImage(
                spot: spot,
                width: 68,
                height: 68,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${spot.city} • ${spot.bestTime}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 5),
                    Text('★ ${spot.rating} • ${spot.category}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Detay',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  IconButton(
                    tooltip: 'Rota',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoutePlannerScreen(initialSpot: spot))),
                    icon: const Icon(Icons.route_outlined, size: 20),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyCard(String text, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white24),
            const SizedBox(width: 11),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white54))),
          ],
        ),
      );
}
