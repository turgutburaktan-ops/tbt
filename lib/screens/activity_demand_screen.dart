import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/turkey_selection_data.dart';
import '../models/social_event.dart';
import '../services/activity_demand_service.dart';
import '../services/social_event_service.dart';
import '../widgets/searchable_selection_field.dart';
import 'event_location_picker_screen.dart';

class ActivityDemandScreen extends StatefulWidget {
  final String? initialActivity;
  final String? initialCity;

  const ActivityDemandScreen({
    super.key,
    this.initialActivity,
    this.initialCity,
  });

  @override
  State<ActivityDemandScreen> createState() => _ActivityDemandScreenState();
}

class _ActivityDemandScreenState extends State<ActivityDemandScreen> {
  static const _background = Color(0xFF090A0C);
  static const _panel = Color(0xFF15181B);
  static const _border = Color(0xFF292D32);
  static const _accent = Color(0xFF42F5E9);

  final _cityController = TextEditingController(text: 'Elazığ');
  String _window = 'today';
  String _activity = 'Fotoğraf';
  bool _busy = false;

  static const activities = <String>[
    'Fotoğraf',
    'Kahve',
    'Yürüyüş',
    'Kamp',
    'Spor',
    'Oyun',
    'Müzik',
    'Gezi',
  ];

  @override
  void initState() {
    super.initState();
    final initialCity = (widget.initialCity ?? '').trim();
    if (initialCity.isNotEmpty) _cityController.text = initialCity;
    if (widget.initialActivity != null && activities.contains(widget.initialActivity)) {
      _activity = widget.initialActivity!;
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  SocialEventType _eventType(String value) => switch (value) {
        'Fotoğraf' => SocialEventType.photography,
        'Yürüyüş' => SocialEventType.walking,
        'Kamp' => SocialEventType.camping,
        'Oyun' => SocialEventType.gaming,
        'Gezi' => SocialEventType.trip,
        'Kahve' => SocialEventType.foodDrink,
        _ => SocialEventType.social,
      };

  DateTime _startForWindow() {
    final now = DateTime.now();
    if (_window == 'tomorrow') {
      return DateTime(now.year, now.month, now.day + 1, 19);
    }
    if (_window == 'weekend') {
      final days = (DateTime.saturday - now.weekday + 7) % 7;
      final target = now.add(Duration(days: days == 0 ? 7 : days));
      return DateTime(target.year, target.month, target.day, 16);
    }
    return now.add(const Duration(hours: 2));
  }

  Future<void> _toggleHere(bool selected) async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Buradayım durumunu paylaşmak için giriş yapmalısın.');
      return;
    }
    if (_cityController.text.trim().length < 2) {
      _message('Önce şehir seçmelisin.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (selected) {
        await ActivityDemandService.instance.removeDemand(
          activity: _activity,
          city: _cityController.text,
          window: _window,
        );
        _message('Buradayım durumun kapatıldı.');
      } else {
        await ActivityDemandService.instance.setDemand(
          activity: _activity,
          city: _cityController.text,
          window: _window,
        );
        _message('Buradayım aktif. Kesin konumun paylaşılmaz.');
      }
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createMeetup(int interestedCount) async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Buluşalım oluşturmak için giriş yapmalısın.');
      return;
    }
    if (_cityController.text.trim().length < 2) {
      _message('Önce şehir seçmelisin.');
      return;
    }

    final location = await Navigator.push<EventLocationSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => EventLocationPickerScreen(
          city: _cityController.text.trim(),
          addressLabel: '$_activity buluşması',
        ),
      ),
    );
    if (location == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await SocialEventService.instance.create(
        title: '$_activity buluşması',
        type: _eventType(_activity),
        startsAt: _startForWindow(),
        capacity: interestedCount.clamp(4, 50),
        city: _cityController.text.trim(),
        locationLabel: location.label,
        description:
            'Aynı aktiviteyi yapmak isteyen TBT kullanıcıları için oluşturuldu.',
        latitude: location.latitude,
        longitude: location.longitude,
        visibility: EventVisibility.public,
      );
      if (!mounted) return;
      _message('Buluşalım oluşturuldu ve Çevrende akışına eklendi.');
      Navigator.pop(context, true);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Buradayım / Buluşalım'),
      ),
      body: StreamBuilder<List<ActivityDemand>>(
        stream: ActivityDemandService.instance.watchActive(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <ActivityDemand>[];
          final matching = all
              .where(
                (d) => ActivityDemandService.instance.matches(
                  d,
                  activity: _activity,
                  city: _cityController.text,
                  window: _window,
                ),
              )
              .toList();
          final selected = uid != null && matching.any((d) => d.userId == uid);
          final count = matching.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: _accent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Buradayım yalnızca şehir ve aktivite sinyali paylaşır. Kesin konumun ve canlı koordinatın diğer kullanıcılara gösterilmez.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SearchableSelectionField(
                controller: _cityController,
                options: turkeyCities,
                labelText: 'Şehir',
                hintText: 'Yazmaya başla ve seç',
                prefixIcon: Icons.location_city_outlined,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activities
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item),
                        selected: _activity == item,
                        onSelected: (_) => setState(() => _activity = item),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('Bugün')),
                  ButtonSegment(value: 'tomorrow', label: Text('Yarın')),
                  ButtonSegment(value: 'weekend', label: Text('Hafta sonu')),
                ],
                selected: {_window},
                onSelectionChanged: (value) =>
                    setState(() => _window = value.first),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_activity • ${_cityController.text.trim().isEmpty ? 'Şehir seç' : _cityController.text.trim()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$count kişi aynı aktiviteyle ilgileniyor',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Buradayım ile sinyal ver veya Buluşalım ile herkese açık bir plan oluştur.',
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _toggleHere(selected),
                        icon: Icon(
                          selected
                              ? Icons.location_on_rounded
                              : Icons.location_on_outlined,
                        ),
                        label: Text(
                          selected ? 'Buradayım Aktif ✓' : 'Buradayım',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _createMeetup(count),
                        icon: const Icon(Icons.groups_2_outlined),
                        label: const Text('Buluşalım Oluştur'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Şu an popüler sinyaller',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...activities.map((activity) {
                final activityCount = all
                    .where(
                      (d) => ActivityDemandService.instance.matches(
                        d,
                        activity: activity,
                        city: _cityController.text,
                        window: _window,
                      ),
                    )
                    .length;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bolt_rounded),
                  title: Text(activity),
                  trailing: Text(
                    '$activityCount kişi',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () => setState(() => _activity = activity),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
