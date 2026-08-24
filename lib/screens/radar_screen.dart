import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/turkey_selection_data.dart';
import '../models/social_event.dart';
import '../services/activity_demand_service.dart';
import '../services/social_event_service.dart';
import '../theme/app_theme.dart';
import '../widgets/searchable_selection_field.dart';
import 'activity_demand_screen.dart';
import 'event_deep_link_screen.dart';
import 'event_photo_create_screen.dart';

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
  String _category = 'Tümü';
  String? _joiningEventId;

  static const _quickActivities = <String>[
    'Fotoğraf',
    'Kahve',
    'Yürüyüş',
    'Kamp',
    'Koşu',
    'Gezi',
  ];

  static const _categories = <String>[
    'Tümü',
    'Sosyal',
    'Fotoğraf',
    'Spor',
    'Kahve',
    'Gezi',
    'Doğa',
    'Müzik',
  ];

  @override
  void initState() {
    super.initState();
    _load();
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
      if (!mounted) return;
      setState(() => _cityController.text = savedCity);
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
      return start.isBefore(now.add(const Duration(hours: 3))) &&
          start.isAfter(now.subtract(const Duration(minutes: 30)));
    }
    if (_period == 'today') {
      return start.year == now.year &&
          start.month == now.month &&
          start.day == now.day &&
          start.isAfter(now.subtract(const Duration(minutes: 30)));
    }
    return start.isBefore(now.add(const Duration(days: 7))) &&
        start.isAfter(now.subtract(const Duration(minutes: 30)));
  }

  bool _demandInPeriod(ActivityDemand demand) {
    if (_period == 'now') return demand.window == 'today';
    if (_period == 'today') {
      return demand.window == 'today' || demand.window == 'tomorrow';
    }
    return true;
  }

  bool _matchesCategory(SocialEvent event) {
    if (_category == 'Tümü') return true;
    return switch (_category) {
      'Fotoğraf' => event.type == SocialEventType.photography,
      'Spor' => {
        SocialEventType.cycling,
        SocialEventType.running,
        SocialEventType.walking,
      }.contains(event.type),
      'Kahve' =>
        event.type == SocialEventType.foodDrink ||
            _normalize(event.title).contains('kahve'),
      'Gezi' => event.type == SocialEventType.trip,
      'Doğa' => {
        SocialEventType.hiking,
        SocialEventType.camping,
      }.contains(event.type),
      'Müzik' => {
        SocialEventType.concert,
        SocialEventType.festival,
        SocialEventType.dance,
      }.contains(event.type),
      'Sosyal' => {
        SocialEventType.social,
        SocialEventType.followerMeetup,
        SocialEventType.networking,
        SocialEventType.party,
      }.contains(event.type),
      _ => true,
    };
  }

  IconData _activityIcon(String activity) => switch (_normalize(activity)) {
    'fotograf' => Icons.photo_camera_outlined,
    'kahve' => Icons.local_cafe_outlined,
    'yuruyus' => Icons.directions_walk_rounded,
    'kosu' => Icons.directions_run_rounded,
    'kamp' => Icons.terrain_outlined,
    'spor' => Icons.sports_basketball_outlined,
    'oyun' => Icons.sports_esports_outlined,
    'muzik' => Icons.music_note_rounded,
    'gezi' => Icons.route_outlined,
    _ => Icons.bolt_rounded,
  };

  IconData _eventIcon(SocialEventType type) => switch (type) {
    SocialEventType.photography => Icons.photo_camera_outlined,
    SocialEventType.cycling => Icons.directions_bike_rounded,
    SocialEventType.running => Icons.directions_run_rounded,
    SocialEventType.walking => Icons.directions_walk_rounded,
    SocialEventType.hiking => Icons.terrain_outlined,
    SocialEventType.camping => Icons.cabin_outlined,
    SocialEventType.concert => Icons.music_note_rounded,
    SocialEventType.festival => Icons.festival_outlined,
    SocialEventType.foodDrink => Icons.local_cafe_outlined,
    SocialEventType.trip => Icons.route_outlined,
    SocialEventType.gaming => Icons.sports_esports_outlined,
    SocialEventType.cinema => Icons.movie_outlined,
    SocialEventType.theatre => Icons.theater_comedy_outlined,
    _ => Icons.groups_2_outlined,
  };

  String _windowLabel(String window) => switch (window) {
    'tomorrow' => 'Yarın',
    'weekend' => 'Hafta sonu',
    _ => 'Bugün',
  };

  String _timeUntil(DateTime value) {
    final diff = value.toLocal().difference(DateTime.now());
    if (diff.isNegative) return 'Başladı';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk sonra';
    if (diff.inHours < 24) {
      final minute = diff.inMinutes.remainder(60);
      return minute == 0
          ? '${diff.inHours} sa sonra'
          : '${diff.inHours} sa ${minute} dk sonra';
    }
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

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

  void _openEvent(SocialEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDeepLinkScreen(eventId: event.id)),
    );
  }

  Future<void> _joinNow(SocialEvent event) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _message('Katılmak için giriş yapmalısın.');
      return;
    }
    if (event.hostId == uid || event.participantIds.contains(uid)) {
      _openEvent(event);
      return;
    }
    if (event.isFull) {
      _message('Bu etkinlik dolmuş.');
      return;
    }
    if (_joiningEventId != null) return;
    setState(() => _joiningEventId = event.id);
    try {
      await SocialEventService.instance.join(event.id);
      _message('Harika! Etkinliğe katıldın 🎉');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _joiningEventId = null);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
                final allEvents = eventSnapshot.data ?? const <SocialEvent>[];
                final events =
                    allEvents
                        .where(
                          (e) =>
                              _sameCity(e.city) &&
                              _eventInPeriod(e) &&
                              _matchesCategory(e),
                        )
                        .toList()
                      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                final soon = events
                    .where(
                      (e) => e.startsAt.isBefore(
                        DateTime.now().add(const Duration(hours: 3)),
                      ),
                    )
                    .take(8)
                    .toList();
                final popular = [...events]
                  ..sort(
                    (a, b) => b.participantCount.compareTo(a.participantCount),
                  );

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
                      const SizedBox(height: 10),
                      _categoryStrip(),
                      const SizedBox(height: 12),
                      _hero(events, demands),
                      const SizedBox(height: 18),
                      _sectionTitle(
                        '⚡ Şimdi Çık',
                        'Önümüzdeki 3 saat içinde başlayacak planlar',
                      ),
                      const SizedBox(height: 9),
                      _eventRail(soon),
                      const SizedBox(height: 20),
                      _sectionTitle(
                        '🔥 Şehrin hareketli planları',
                        'Katılımı en yüksek etkinlikler',
                      ),
                      const SizedBox(height: 9),
                      _eventRail(popular.take(8).toList()),
                      const SizedBox(height: 20),
                      _sectionTitle(
                        'Şu an ne yapmak istiyorlar?',
                        'Aynı planı isteyen insanlarla buluş',
                      ),
                      const SizedBox(height: 9),
                      _demandSection(demands),
                      const SizedBox(height: 20),
                      _sectionTitle(
                        '⚡ Planı sen başlat',
                        'Bir fikir seç, çevrendekilere haber ver',
                      ),
                      const SizedBox(height: 9),
                      _quickStartStrip(alwaysShow: true),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              if (FirebaseAuth.instance.currentUser == null) {
                _message('Etkinlik oluşturmak için giriş yapmalısın.');
                return;
              }
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const EventPhotoCreateScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Etkinlik Oluştur'),
          ),
        ),
        const SizedBox(height: 10),
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

  Widget _categoryStrip() => SizedBox(
    height: 37,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (context, index) {
        final label = _categories[index];
        final selected = _category == label;
        return ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _category = label),
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: selected ? AppColors.cyan : AppColors.border),
        );
      },
    ),
  );

  Widget _hero(List<SocialEvent> events, List<ActivityDemand> demands) {
    final participantIds = <String>{};
    for (final event in events) {
      participantIds.addAll(event.participantIds);
    }
    participantIds.addAll(demands.map((e) => e.userId));
    final city = _cityController.text.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF142129), Color(0xFF1D1529)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _LiveDot(),
              SizedBox(width: 8),
              Text(
                'ŞEHİR ŞU AN HAREKETLİ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            city.isEmpty
                ? 'Bugün ne yapmak istersin?'
                : '$city’da bugün ne yapmak istersin?',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${events.length} etkinlik • ${participantIds.length} aktif kişi',
            style: const TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                if (events.isNotEmpty) {
                  _openEvent(events.first);
                } else {
                  _openActivity('Sosyal');
                }
              },
              icon: const Icon(Icons.bolt_rounded),
              label: Text(
                events.isEmpty ? 'İlk planı başlat' : 'Şimdi bir plan bul',
              ),
            ),
          ),
        ],
      ),
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
              color: selected ? Colors.white : const Color(0x75FFFFFF),
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventRail(List<SocialEvent> events) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Şimdilik uygun etkinlik yok. İlk planı sen başlatabilirsin.',
          style: TextStyle(color: Colors.white54, height: 1.35),
        ),
      );
    }
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) => _eventCard(events[index]),
      ),
    );
  }

  Widget _eventCard(SocialEvent event) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final joined =
        uid != null &&
        (event.hostId == uid || event.participantIds.contains(uid));
    final loading = _joiningEventId == event.id;
    final remaining = event.remainingSlots.clamp(0, event.capacity);
    return SizedBox(
      width: 228,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _openEvent(event),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceStrong,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _eventIcon(event.type),
                        size: 19,
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _timeUntil(event.startsAt),
                            style: const TextStyle(
                              color: AppColors.cyan,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            event.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_2_outlined,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${event.participantCount}/${event.capacity}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (remaining <= 2 && remaining > 0) ...[
                      const SizedBox(width: 7),
                      Text(
                        'Son $remaining yer',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  height: 35,
                  child: FilledButton(
                    onPressed: loading || event.isFull
                        ? null
                        : () => _joinNow(event),
                    child: loading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            joined
                                ? 'Detayları Gör'
                                : event.isFull
                                ? 'Dolu'
                                : 'Ben de Geliyorum',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
      width: 155,
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

  Widget _quickStartStrip({bool alwaysShow = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!alwaysShow) ...[
          const Text(
            'Şu an sakin. İlk hareketi sen başlat.',
            style: TextStyle(color: Color(0x75FFFFFF), fontSize: 11.5),
          ),
          const SizedBox(height: 8),
        ],
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
