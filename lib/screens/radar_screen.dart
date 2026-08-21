import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/turkey_selection_data.dart';
import '../models/photo_spot.dart';
import '../models/social_event.dart';
import '../services/activity_demand_service.dart';
import '../services/social_event_service.dart';
import '../services/spot_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/searchable_selection_field.dart';
import '../widgets/spot_image.dart';
import 'activity_demand_screen.dart';
import 'route_planner_screen.dart';
import 'spot_detail_screen.dart';

class RadarScreen extends StatefulWidget {
  final bool embedded;

  const RadarScreen({super.key, this.embedded = false});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  static const _cityPrefKey = 'radar_city';

  final _cityController = TextEditingController();
  String _period = 'now';
  int _spotMode = 0;
  List<PhotoSpot> _spots = const [];
  Position? _position;
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
    _readLocation();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
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

  Future<void> _readLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() => _position = position);
    } catch (_) {}
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

  double _distance(PhotoSpot spot) {
    final p = _position;
    if (p == null) return double.infinity;
    return Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      spot.latitude,
      spot.longitude,
    );
  }

  String _distanceLabel(PhotoSpot spot) {
    final meters = _distance(spot);
    if (!meters.isFinite) return '';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  List<PhotoSpot> get _visibleSpots {
    final result = _spots.where((spot) => _sameCity(spot.city)).toList();
    if (_spotMode == 0 && _position != null) {
      result.sort((a, b) => _distance(a).compareTo(_distance(b)));
    } else {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return result.take(8).toList();
  }

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

  String _windowLabel(String window) => switch (window) {
        'tomorrow' => 'Yarın',
        'weekend' => 'Hafta sonu',
        _ => 'Bugün',
      };

  void _openActivity(String activity, {String? city}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDemandScreen(
          initialActivity: activity,
          initialCity: (city ?? _cityController.text).trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  color: AppColors.cyan,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      14,
                      6,
                      14,
                      widget.embedded ? 22 : 92,
                    ),
                    children: [
                      _header(),
                      const SizedBox(height: 9),
                      _summaryStrip(demands, events),
                      const SizedBox(height: 18),
                      _sectionTitle(
                        'Şu an hareketli',
                        'İnsanların yapmak istediği şeyler',
                      ),
                      const SizedBox(height: 9),
                      _demandSection(demands),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionHeading(
                              title: 'Çekim fırsatları',
                              subtitle: 'Doğru noktayı hızlı bul',
                            ),
                          ),
                          _SpotModeButton(
                            label: 'Yakındakiler',
                            selected: _spotMode == 0,
                            onTap: () => setState(() => _spotMode = 0),
                          ),
                          const SizedBox(width: 5),
                          _SpotModeButton(
                            label: 'Popüler',
                            selected: _spotMode == 1,
                            onTap: () => setState(() => _spotMode = 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
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
          const Row(
            children: [
              Icon(Icons.radar_rounded, color: AppColors.cyan, size: 22),
              SizedBox(width: 8),
              Text(
                'Radar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.border),
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
      color: selected ? AppColors.surfaceStrong : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _period = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white46,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryStrip(List<ActivityDemand> demands, List<SocialEvent> events) {
    final people = demands.map((d) => d.userId).toSet().length;
    final spots = _visibleSpots.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const _LiveDot(),
          const SizedBox(width: 7),
          const Text(
            'Radar hazır',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          _compactMetric(Icons.groups_2_outlined, '$people kişi'),
          const SizedBox(width: 10),
          _compactMetric(Icons.event_outlined, '${events.length} etkinlik'),
          const SizedBox(width: 10),
          _compactMetric(Icons.photo_camera_outlined, '$spots çekim'),
        ],
      ),
    );
  }

  Widget _compactMetric(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  Widget _sectionTitle(String title, String subtitle) =>
      _SectionHeading(title: title, subtitle: subtitle);

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
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.take(6).length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final items = groups[index];
          return _demandCard(items.first, items.length);
        },
      ),
    );
  }

  Widget _demandCard(ActivityDemand demand, int count) {
    return SizedBox(
      width: 142,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openActivity(demand.activity, city: demand.city),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    _activityIcon(demand.activity),
                    size: 18,
                    color: AppColors.cyan,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        demand.activity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$count kişi • ${_windowLabel(demand.window)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.8,
                        ),
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

  Widget _quickStartStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Şu an sakin. İlk hareketi sen başlat.',
          style: TextStyle(color: Colors.white46, fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _quickActivities.map((activity) {
            return ActionChip(
              avatar: Icon(_activityIcon(activity), size: 16),
              label: Text(activity),
              onPressed: () => _openActivity(activity),
            );
          }).toList(),
        ),
      ],
    );
  }

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
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: spots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) => _spotCard(spots[index]),
      ),
    );
  }

  Widget _spotCard(PhotoSpot spot) {
    return SizedBox(
      width: 214,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SpotImage(
                      spot: spot,
                      width: 214,
                      height: 130,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .66),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '★ ${spot.rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 9.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (_spotMode == 0 && _position != null)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .66),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _distanceLabel(spot),
                            style: const TextStyle(
                              color: AppColors.cyan,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 7,
                      bottom: 7,
                      child: IconButton(
                        tooltip: 'Rota oluştur',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoutePlannerScreen(initialSpot: spot),
                          ),
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                          backgroundColor: Colors.black.withValues(alpha: .70),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.route_outlined, size: 17),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${spot.city}  •  ${spot.bestTime}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.8,
                        ),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white30, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white46, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 10.5),
          ),
        ],
      );
}

class _SpotModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpotModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.surfaceStrong : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.cyan.withValues(alpha: .48)
                    : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white46,
                fontSize: 9.8,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
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
          color: AppColors.cyan,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
