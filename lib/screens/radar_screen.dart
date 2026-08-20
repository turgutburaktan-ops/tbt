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
  final bool embedded;

  const RadarScreen({super.key, this.embedded = false});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  static const _background = Color(0xFF090A0C);
  static const _surface = Color(0xFF121416);
  static const _surfaceAlt = Color(0xFF191C20);
  static const _surfaceStrong = Color(0xFF20242A);
  static const _border = Color(0xFF292D32);
  static const _accent = Color(0xFFB7BCC2);
  static const _cityPrefKey = 'radar_city';

  final _cityController = TextEditingController();
  String _period = 'now';
  List<PhotoSpot> _spots = const [];
  bool _loadingSpots = true;

  static const _quickActivities = <String>[
    'Fotoğraf',
    'Kahve',
    'Yürüyüş',
    'Kamp',
  ];

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
    if (mounted) setState(() {});
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
    return result.take(6).toList();
  }

  String _eventTime(SocialEvent event) {
    final now = DateTime.now();
    final d = event.startsAt.toLocal();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day;
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'Bugün • $time';
    if (isTomorrow) return 'Yarın • $time';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} • $time';
  }

  String _eventDay(SocialEvent event) {
    final now = DateTime.now();
    final d = event.startsAt.toLocal();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'BUGÜN';
    }
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day) {
      return 'YARIN';
    }
    return d.day.toString().padLeft(2, '0');
  }

  String _eventMonth(SocialEvent event) {
    final d = event.startsAt.toLocal();
    const months = <String>[
      'OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ',
      'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA',
    ];
    return months[d.month - 1];
  }

  String _windowLabel(String window) => switch (window) {
        'tomorrow' => 'Yarın',
        'weekend' => 'Hafta sonu',
        _ => 'Bugün',
      };

  IconData _activityIcon(String activity) => switch (_normalize(activity)) {
        'fotograf' => Icons.photo_camera_outlined,
        'kahve' => Icons.local_cafe_outlined,
        'yuruyus' => Icons.directions_walk_rounded,
        'kamp' => Icons.terrain_outlined,
        'spor' => Icons.sports_basketball_outlined,
        'oyun' => Icons.sports_esports_outlined,
        'muzik' => Icons.music_note_rounded,
        'gezi' => Icons.route_outlined,
        _ => Icons.bolt_rounded,
      };

  void _openActivity(String activity, {String? city}) {
    final selectedCity = (city ?? _cityController.text).trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDemandScreen(
          initialActivity: activity,
          initialCity: selectedCity,
        ),
      ),
    );
  }

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
                    padding: EdgeInsets.fromLTRB(
                      14,
                      8,
                      14,
                      widget.embedded ? 24 : 112,
                    ),
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      _summaryCard(demands, events),
                      const SizedBox(height: 25),
                      _sectionTitle(
                        'Şu an hareketli',
                        'İnsanların yapmak istediği şeyler',
                        Icons.bolt_rounded,
                      ),
                      const SizedBox(height: 11),
                      _demandSection(demands),
                      const SizedBox(height: 26),
                      _sectionTitle(
                        'Çekim fırsatları',
                        _cityController.text.trim().isEmpty
                            ? 'Türkiye genelinden güçlü noktalar'
                            : '${_cityController.text.trim()} için güçlü noktalar',
                        Icons.photo_camera_outlined,
                      ),
                      const SizedBox(height: 11),
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
        if (!widget.embedded) ...[
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _surfaceStrong,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child:
                    const Icon(Icons.radar_rounded, color: _accent, size: 24),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radar',
                      style:
                          TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Çevrende ne oluyor?',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Bildirimler',
                onPressed: () =>
                    Navigator.pushNamed(context, '/notifications'),
                icon: const Icon(Icons.notifications_none_rounded, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 15),
        ],
        SearchableSelectionField(
          controller: _cityController,
          options: turkeyCities,
          labelText: 'Şehir',
          hintText: 'Şehir seç veya Türkiye geneli bırak',
          prefixIcon: Icons.location_city_outlined,
          onChanged: _setCity,
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
        ? 'Çevrende hareket var'
        : score >= 8
            ? 'Radar hareketleniyor'
            : 'Radar hazır';
    final subtitle = _cityController.text.trim().isEmpty
        ? 'Türkiye genelindeki güncel hareketler'
        : '${_cityController.text.trim()} • canlı görünüm';

    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_surfaceStrong, _surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF34393F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LiveDot(),
                    SizedBox(width: 6),
                    Text(
                      'CANLI',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.radar_rounded, color: Colors.white24, size: 30),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _metricBlock(
                  value: '$people',
                  label: 'kişi',
                  icon: Icons.groups_2_outlined,
                ),
              ),
              _metricDivider(),
              Expanded(
                child: _metricBlock(
                  value: '${events.length}',
                  label: 'etkinlik',
                  icon: Icons.event_outlined,
                ),
              ),
              _metricDivider(),
              Expanded(
                child: _metricBlock(
                  value: '$spots',
                  label: 'çekim',
                  icon: Icons.photo_camera_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricBlock({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _accent),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11),
        ),
      ],
    );
  }

  Widget _metricDivider() => Container(
        width: 1,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 9),
        color: Colors.white10,
      );

  Widget _sectionTitle(String title, String subtitle, IconData icon) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, size: 19, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _demandSection(List<ActivityDemand> demands) {
    final grouped = <String, List<ActivityDemand>>{};
    for (final demand in demands) {
      final key = '${demand.activity}|${demand.city}|${demand.window}';
      grouped.putIfAbsent(key, () => []).add(demand);
    }
    final groups = grouped.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    if (groups.isEmpty) return _quickStartStrip();

    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.take(6).length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final items = groups[index];
          final first = items.first;
          return _demandCard(first, items.length);
        },
      ),
    );
  }

  Widget _demandCard(ActivityDemand demand, int count) {
    return SizedBox(
      width: 164,
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openActivity(demand.activity, city: demand.city),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        _activityIcon(demand.activity),
                        size: 18,
                        color: _accent,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_outward_rounded,
                      size: 17,
                      color: Colors.white30,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '$count',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                Text(
                  demand.activity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${demand.city} • ${_windowLabel(demand.window)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickStartStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 19, color: _accent),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Şu an sakin. İlk hareketi sen başlat.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickActivities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final activity = _quickActivities[index];
              return ActionChip(
                avatar: Icon(_activityIcon(activity), size: 17),
                label: Text(activity),
                onPressed: () => _openActivity(activity),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _eventSection(List<SocialEvent> events) {
    if (events.isEmpty) {
      return _emptyCard(
        'Bu filtrede yaklaşan etkinlik yok. Radar yenilendikçe burada görünecek.',
        Icons.event_busy_outlined,
      );
    }
    return Column(children: events.take(4).map(_eventCard).toList());
  }

  Widget _communityEventSection(List<SocialEvent> events) {
    return Column(children: events.take(3).map(_eventCard).toList());
  }

  Widget _eventCard(SocialEvent event) {
    final capacity = event.capacity <= 0 ? 1 : event.capacity;
    final occupancy = (event.participantCount / capacity).clamp(0.0, 1.0);
    final community = (event.communityName ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDeepLinkScreen(eventId: event.id),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 62,
                  decoration: BoxDecoration(
                    color: _surfaceStrong,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _eventDay(event),
                        style: TextStyle(
                          fontSize: _eventDay(event).length > 2 ? 10 : 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _eventMonth(event),
                        style: const TextStyle(
                          color: Color(0x73FFFFFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_eventTime(event)} • ${event.city.isEmpty ? 'Konum detayda' : event.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      if (community.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          community,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 10),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          _tinyBadge(
                            Icons.groups_2_outlined,
                            '${event.participantCount}/${event.capacity}',
                          ),
                          const SizedBox(width: 6),
                          _tinyBadge(
                            event.isPaid
                                ? Icons.payments_outlined
                                : Icons.confirmation_number_outlined,
                            event.isPaid
                                ? '${event.ticketPrice.toStringAsFixed(0)} TL'
                                : 'Ücretsiz',
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: occupancy,
                          minHeight: 3,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tinyBadge(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: _surfaceAlt,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );

  Widget _spotSection() {
    if (_loadingSpots) {
      return const SizedBox(
        height: 210,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final spots = _visibleSpots;
    if (spots.isEmpty) {
      return _emptyCard(
        'Bu şehir için uygun çekim noktası bulunamadı.',
        Icons.photo_camera_back_outlined,
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: spots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _spotCard(spots[index]),
      ),
    );
  }

  Widget _spotCard(PhotoSpot spot) {
    return SizedBox(
      width: 240,
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SpotImage(
                      spot: spot,
                      width: 240,
                      height: 142,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                    ),
                    Positioned(
                      top: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '★ ${spot.rating}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IconButton.filled(
                        tooltip: 'Rota oluştur',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .68),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoutePlannerScreen(initialSpot: spot),
                          ),
                        ),
                        icon: const Icon(Icons.route_outlined, size: 18),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${spot.city} • ${spot.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              spot.bestTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String text, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white30, size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white54, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: .35, end: 1).animate(_controller),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFFD6DBE0),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
