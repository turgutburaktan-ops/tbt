import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/turkey_selection_data.dart';
import '../models/social_event.dart';
import '../services/activity_demand_service.dart';
import '../widgets/searchable_selection_field.dart';
import 'event_create_screen_v2.dart';
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
  final _cityController = TextEditingController(text: 'Elazığ');
  String _window = 'today';
  String _activity = 'Fotoğraf';
  bool _busy = false;

  static const activities = <String>[
    'Fotoğraf', 'Kahve', 'Yürüyüş', 'Kamp', 'Spor', 'Oyun', 'Müzik', 'Gezi'
  ];

  @override
  void initState() {
    super.initState();
    if ((widget.initialCity ?? '').trim().isNotEmpty) {
      _cityController.text = widget.initialCity!.trim();
    }
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
        'Spor' => SocialEventType.social,
        'Oyun' => SocialEventType.gaming,
        'Müzik' => SocialEventType.social,
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

  Future<void> _toggleDemand(bool selected) async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Katılmak için giriş yapmalısın.');
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
      } else {
        await ActivityDemandService.instance.setDemand(
          activity: _activity,
          city: _cityController.text,
          window: _window,
        );
      }
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createMeetup(int interestedCount) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Buluşma oluşturmak için giriş yapmalısın.');
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

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EventCreateScreenV2(
          initialTitle: '$_activity buluşması',
          initialType: _eventType(_activity),
          initialStartsAt: _startForWindow(),
          initialCapacity: interestedCount.clamp(4, 50),
          initialCity: _cityController.text.trim(),
          initialLocationLabel: location.label,
          initialDescription:
              'Bu buluşma aynı aktiviteyi yapmak isteyen kullanıcıların talebinden oluşturuldu.',
          initialLatitude: location.latitude,
          initialLongitude: location.longitude,
        ),
      ),
    );
    if (created == true && mounted) {
      _message('Buluşma oluşturuldu.');
      Navigator.pop(context, true);
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
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        title: const Text('Bugün ne yapmak istiyorsun?'),
      ),
      body: StreamBuilder<List<ActivityDemand>>(
        stream: ActivityDemandService.instance.watchActive(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <ActivityDemand>[];
          final matching = all.where((d) => ActivityDemandService.instance.matches(
                d,
                activity: _activity,
                city: _cityController.text,
                window: _window,
              )).toList();
          final selected = uid != null && matching.any((d) => d.userId == uid);
          final count = matching.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              const Text(
                'Etkinlik beklemek yerine aynı şeyi yapmak isteyenleri önce burada buluşturuyoruz.',
                style: TextStyle(color: Colors.white60, height: 1.45),
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
                children: activities.map((item) => ChoiceChip(
                  label: Text(item),
                  selected: _activity == item,
                  onSelected: (_) => setState(() => _activity = item),
                )).toList(),
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('Bugün')),
                  ButtonSegment(value: 'tomorrow', label: Text('Yarın')),
                  ButtonSegment(value: 'weekend', label: Text('Hafta sonu')),
                ],
                selected: {_window},
                onSelectionChanged: (value) => setState(() => _window = value.first),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF15181B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF292D32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_activity • ${_cityController.text.trim().isEmpty ? 'Şehir seç' : _cityController.text.trim()}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('$count kişi aynı şeyi yapmak istiyor',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      count >= 20
                          ? 'Talep güçlü. Bir buluşma başlatmak için iyi zaman.'
                          : 'Talep biriktikçe bu aktivite daha görünür olacak.',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _toggleDemand(selected),
                        icon: Icon(selected ? Icons.check_circle : Icons.add_circle_outline),
                        label: Text(selected ? 'Ben de istiyorum ✓' : 'Ben de istiyorum'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _createMeetup(count),
                        icon: const Icon(Icons.groups_2_outlined),
                        label: const Text('Buluşma Başlat'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Şu an popüler talepler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ...activities.map((activity) {
                final activityCount = all.where((d) => ActivityDemandService.instance.matches(
                      d,
                      activity: activity,
                      city: _cityController.text,
                      window: _window,
                    )).length;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(activity),
                  trailing: Text('$activityCount kişi',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
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
