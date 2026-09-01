import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';
import '../services/nearby_venue_service.dart';
import '../services/spot_repository.dart';
import '../services/travel_intelligence_service.dart';
import '../services/travel_plan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/spot_image.dart';
import 'route_planner_screen.dart';
import 'travel_plan_invite_screen.dart';

class SmartPlanScreen extends StatefulWidget {
  final bool inviteAfterSave;

  const SmartPlanScreen({super.key, this.inviteAfterSave = false});

  @override
  State<SmartPlanScreen> createState() => _SmartPlanScreenState();
}

class _SmartPlanScreenState extends State<SmartPlanScreen> {
  static const _interests = <String>[
    'Tarih',
    'Doğa',
    'Fotoğraf',
    'Mimari',
    'Manzara',
    'Yürüyüş',
  ];

  final _title = TextEditingController();
  final _prompt = TextEditingController();
  List<PhotoSpot> _allSpots = const [];
  List<PhotoSpot> _generated = const [];
  List<String> _cities = const [];
  final Set<String> _selectedInterests = {'Fotoğraf'};
  String? _city;
  int _duration = 5;
  String _budget = 'Orta';
  String _transport = 'Araç';
  bool _loading = true;
  bool _saving = false;
  bool _generating = false;
  bool _addFood = true;
  bool _addCafe = true;
  bool _addBreakfast = false;
  bool _addDessert = false;
  bool _addHotel = false;
  String _area = 'Tüm şehir';
  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));
  RouteIntelligence? _intelligence;
  int _estimatedBudget = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final spots = await SpotRepository.instance.loadSpots();
      final cities = spots
          .map((spot) => spot.city.trim())
          .where((city) => city.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _allSpots = spots;
        _cities = cities;
        _city = cities.contains('İstanbul')
            ? 'İstanbul'
            : cities.isEmpty
            ? null
            : cities.first;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  double _score(PhotoSpot spot) {
    final searchable = _normalize(
      '${spot.name} ${spot.category} ${spot.description} ${spot.tags.join(' ')}',
    );
    var score = spot.rating * 2;
    for (final interest in _selectedInterests) {
      if (searchable.contains(_normalize(interest))) score += 5;
    }
    if (_budget == 'Ekonomik' && spot.difficulty == 'Kolay') score += 1.5;
    return score;
  }

  double _distance(PhotoSpot a, PhotoSpot b) {
    final lat = a.latitude - b.latitude;
    final lng = a.longitude - b.longitude;
    return math.sqrt(lat * lat + lng * lng);
  }

  static const _areaCenters = <String, (double, double, double)>{
    'Harput': (38.7040, 39.2550, .12),
    'Sivrice': (38.4480, 39.3100, .22),
    'Palu': (38.6910, 39.9500, .24),
    'Keban': (38.7970, 38.7330, .26),
    'Ağın': (38.9440, 38.7110, .24),
  };

  List<String> get _availableAreas =>
      _normalize(_city ?? '') == _normalize('Elazığ')
      ? const ['Tüm şehir', 'Harput', 'Sivrice', 'Palu', 'Keban', 'Ağın']
      : const ['Tüm şehir'];

  bool _inSelectedArea(PhotoSpot spot) {
    final area = _areaCenters[_area];
    if (area == null) return true;
    final lat = spot.latitude - area.$1;
    final lng = spot.longitude - area.$2;
    return math.sqrt(lat * lat + lng * lng) <= area.$3;
  }

  List<PhotoSpot> _orderNearby(List<PhotoSpot> candidates) {
    if (candidates.length < 3) return candidates;
    final remaining = List<PhotoSpot>.from(candidates.skip(1));
    final ordered = <PhotoSpot>[candidates.first];
    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => _distance(ordered.last, a).compareTo(
          _distance(ordered.last, b),
        ),
      );
      ordered.add(remaining.removeAt(0));
    }
    return ordered;
  }

  void _applyPrompt() {
    final prompt = _normalize(_prompt.text);
    if (prompt.trim().isEmpty) return;
    String? city;
    for (final item in _cities) {
      if (prompt.contains(_normalize(item))) {
        city = item;
        break;
      }
    }
    final hourMatch = RegExp(r'(\d{1,2})\s*saat').firstMatch(prompt);
    final parsedHours = int.tryParse(hourMatch?.group(1) ?? '');
    final duration = parsedHours == null
        ? _duration
        : parsedHours <= 3
        ? 3
        : parsedHours <= 6
        ? 5
        : 8;
    final transport = prompt.contains('yuru')
        ? 'Yürüyüş'
        : prompt.contains('bisiklet')
        ? 'Bisiklet'
        : prompt.contains('araba') || prompt.contains('arac')
        ? 'Araç'
        : _transport;
    final budget = prompt.contains('ekonomik') || prompt.contains('ucuz')
        ? 'Ekonomik'
        : prompt.contains('rahat') || prompt.contains('butce sorun degil')
        ? 'Rahat'
        : _budget;
    final interests = <String>{};
    for (final interest in _interests) {
      if (prompt.contains(_normalize(interest))) interests.add(interest);
    }
    setState(() {
      _city = city ?? _city;
      _duration = duration;
      _transport = transport;
      _budget = budget;
      if (interests.isNotEmpty) {
        _selectedInterests
          ..clear()
          ..addAll(interests);
      }
      _addFood = prompt.contains('yemek') || _addFood;
      _addCafe = prompt.contains('kahve') || _addCafe;
      _addBreakfast = prompt.contains('kahvalti') || _addBreakfast;
      _addDessert = prompt.contains('tatli') || _addDessert;
      _addHotel = prompt.contains('otel') || prompt.contains('konaklama');
      _generated = const [];
      _intelligence = null;
    });
    _message('İsteğin seçimlere uygulandı.');
  }

  PhotoSpot _venueSpot(NearbyVenue venue, String city) => PhotoSpot(
    id: 'venue_${venue.category.name}_${venue.id}',
    name: venue.name,
    city: city,
    latitude: venue.latitude,
    longitude: venue.longitude,
    rating: 0,
    bestTime: venue.openingHours,
    angle: '',
    imageUrl: venue.imageUrl,
    category: venue.category.label,
    description: venue.description,
    tags: [venue.category.label, city],
  );

  Future<void> _generate() async {
    final city = _city;
    if (city == null || _generating) return;
    setState(() => _generating = true);
    final count = _duration <= 3
        ? 3
        : _duration <= 5
        ? 5
        : 7;
    final candidates = _allSpots
        .where(
          (spot) =>
              _normalize(spot.city) == _normalize(city) &&
              _inSelectedArea(spot),
        )
        .toList()
      ..sort((a, b) => _score(b).compareTo(_score(a)));
    var selected = _orderNearby(candidates.take(count).toList());
    if (selected.isEmpty) {
      setState(() => _generating = false);
      _message('$city için uygun rota bulunamadı.');
      return;
    }
    try {
      final center = selected[selected.length ~/ 2];
      final categories = <NearbyVenueCategory>[
        if (_addCafe) NearbyVenueCategory.cafe,
        if (_addFood) NearbyVenueCategory.dining,
        if (_addBreakfast) NearbyVenueCategory.dining,
        if (_addDessert) NearbyVenueCategory.cafe,
        if (_addHotel) NearbyVenueCategory.hotel,
      ];
      final venueGroups = await Future.wait(
        categories.map(
          (category) => NearbyVenueService.instance.nearby(
            category: category,
            latitude: center.latitude,
            longitude: center.longitude,
            radiusMeters: 9000,
          ),
        ),
      );
      final usedVenueIds = <String>{};
      final venueStops = <PhotoSpot>[];
      for (final group in venueGroups) {
        for (final venue in group) {
          if (usedVenueIds.add(venue.id)) {
            venueStops.add(_venueSpot(venue, city));
            break;
          }
        }
      }
      final mealLimit = _duration <= 3
          ? 1
          : _duration <= 5
          ? 2
          : 4;
      selected = _orderNearby([
        ...selected,
        ...venueStops.take(mealLimit),
      ]);
    } catch (_) {}
    var intelligence = await TravelIntelligenceService.instance.analyze(
      selected,
      transport: _transport,
    );
    final rainy = intelligence.weatherSummary.contains('Yağmurlu') ||
        intelligence.weatherSummary.contains('Sağanak') ||
        intelligence.weatherSummary.contains('Fırtınalı');
    if (rainy) {
      int indoorScore(PhotoSpot spot) {
        final value = _normalize('${spot.category} ${spot.tags.join(' ')}');
        return value.contains('muze') ||
                value.contains('mimari') ||
                value.contains('kafe') ||
                value.contains('lezzet')
            ? 1
            : 0;
      }
      selected.sort((a, b) => indoorScore(b).compareTo(indoorScore(a)));
      intelligence = await TravelIntelligenceService.instance.analyze(
        selected,
        transport: _transport,
      );
    }
    final estimated = TravelIntelligenceService.instance.estimateBudget(
      distanceKm: intelligence.distanceKm,
      stopCount: selected.length,
      budget: _budget,
      transport: _transport,
      mealStops:
          (_addFood ? 1 : 0) +
          (_addCafe ? 1 : 0) +
          (_addBreakfast ? 1 : 0) +
          (_addDessert ? 1 : 0),
      hotel: _addHotel,
    );
    if (!mounted) return;
    setState(() {
      _generated = selected;
      _intelligence = intelligence;
      _estimatedBudget = estimated;
      _generating = false;
      if (_title.text.trim().isEmpty) {
        final area = _area == 'Tüm şehir' ? city : _area;
        final flavor = _addFood || _addCafe || _addBreakfast || _addDessert
            ? ' gezi ve lezzet rotası'
            : ' gezi rotası';
        _title.text = '$area$flavor';
      }
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickCity() async {
    var query = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) {
          final normalizedQuery = _normalize(query.trim());
          final matches = normalizedQuery.isEmpty
              ? _cities
              : _cities
                    .where(
                      (city) => _normalize(city).contains(normalizedQuery),
                    )
                    .toList(growable: false);
          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .72,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      14,
                      14,
                      MediaQuery.viewInsetsOf(sheetContext).bottom > 0 ? 8 : 12,
                    ),
                    child: TextField(
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Şehir ara',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) =>
                          setSheetState(() => query = value),
                    ),
                  ),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('Şehir bulunamadı'))
                        : ListView.builder(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: matches.length,
                            itemBuilder: (_, index) {
                              final city = matches[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.location_city_outlined,
                                ),
                                title: Text(city),
                                trailing: city == _city
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.cyan,
                                      )
                                    : null,
                                onTap: () =>
                                    Navigator.pop(sheetContext, city),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _city = selected;
      _area = 'Tüm şehir';
      _generated = const [];
      _title.text = '$selected gezi planı';
    });
  }

  Future<void> _shareGenerated() async {
    if (_generated.isEmpty) return;
    final title = _title.text.trim().isEmpty
        ? '${_city ?? ''} gezi planı'
        : _title.text.trim();
    final stops = _generated
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value.name}')
        .join('\n');
    await Share.share(
      '$title\n\n${_city ?? ''} • $_duration saat • $_transport • $_budget\n\n$stops\n\nTBT ile hazırlandı.',
      subject: title,
    );
  }

  Future<void> _save() async {
    if (_generated.isEmpty || _saving) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Planı kaydetmek için giriş yapmalısın.');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await TravelPlanService.instance.create(
        title: _title.text,
        city: _city!,
        durationHours: _duration,
        budget: _budget,
        transport: _transport,
        interests: _selectedInterests.toList(),
        spots: _generated,
        area: _area == 'Tüm şehir' ? '' : _area,
        mealPreferences: [
          if (_addFood) 'Yerel lezzet',
          if (_addCafe) 'Kahve',
          if (_addBreakfast) 'Kahvaltı',
          if (_addDessert) 'Tatlı',
          if (_addHotel) 'Konaklama',
        ],
        startAt: _startAt,
        distanceKm: _intelligence?.distanceKm ?? 0,
        travelMinutes: _intelligence?.travelMinutes ?? 0,
        estimatedBudget: _estimatedBudget,
        weatherSummary: _intelligence?.weatherSummary ?? '',
      );
      if (!mounted) return;
      if (widget.inviteAfterSave) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TravelPlanInviteScreen(
              planId: id,
              planTitle: _title.text.trim(),
            ),
          ),
        );
      } else {
        _message('Planın kaydedildi.');
      }
    } catch (error) {
      if (mounted) _message('Plan kaydedilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Akıllı Plan Oluştur')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: [
                const Text(
                  'Nereye ve nasıl gitmek istediğini seç; TBT sana uygun durakları sıralasın.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _prompt,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Nasıl bir plan istiyorsun?',
                    hintText:
                        'Örn: Elazığ’da arabayla 6 saat, tarih, yemek ve kahve ağırlıklı ekonomik rota',
                    prefixIcon: const Icon(Icons.auto_awesome_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'İsteği uygula',
                      onPressed: _applyPrompt,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                  onSubmitted: (_) => _applyPrompt(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: ValueKey(_city),
                  initialValue: _city ?? '',
                  readOnly: true,
                  onTap: _pickCity,
                  decoration: const InputDecoration(
                    labelText: 'Şehir ara ve seç',
                    prefixIcon: Icon(Icons.location_city_rounded),
                    suffixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Rotanın adı',
                    hintText: 'Örn. Harput tarih ve lezzet rotası',
                    prefixIcon: Icon(Icons.edit_road_rounded),
                  ),
                ),
                if (_availableAreas.length > 1) ...[
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    key: ValueKey('${_city}_$_area'),
                    initialValue: _availableAreas.contains(_area)
                        ? _area
                        : 'Tüm şehir',
                    decoration: const InputDecoration(
                      labelText: 'Hangi bölgede gezeceksin?',
                      prefixIcon: Icon(Icons.near_me_outlined),
                    ),
                    items: _availableAreas
                        .map(
                          (area) => DropdownMenuItem(
                            value: area,
                            child: Text(area),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _area = value ?? 'Tüm şehir';
                      _generated = const [];
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Başlangıç: Konumum'),
                  subtitle: Text(
                    '${_startAt.day.toString().padLeft(2, '0')}.${_startAt.month.toString().padLeft(2, '0')}.${_startAt.year} • ${_startAt.hour.toString().padLeft(2, '0')}:${_startAt.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _startAt.isBefore(DateTime.now())
                          ? DateTime.now()
                          : _startAt,
                    );
                    if (date == null || !mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_startAt),
                    );
                    if (time == null || !mounted) return;
                    setState(() {
                      _startAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
                const SizedBox(height: 18),
                const Text('Ne kadar zamanın var?', style: _sectionStyle),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 3, label: Text('3 saat')),
                    ButtonSegment(value: 5, label: Text('5 saat')),
                    ButtonSegment(value: 8, label: Text('Tam gün')),
                  ],
                  selected: {_duration},
                  onSelectionChanged: (value) =>
                      setState(() => _duration = value.first),
                ),
                const SizedBox(height: 18),
                const Text('İlgi alanların', style: _sectionStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _interests
                      .map(
                        (interest) => FilterChip(
                          label: Text(interest),
                          selected: _selectedInterests.contains(interest),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _selectedInterests.add(interest)
                                : _selectedInterests.remove(interest);
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _budget,
                        decoration: const InputDecoration(labelText: 'Bütçe'),
                        items: const ['Ekonomik', 'Orta', 'Rahat']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _budget = value ?? _budget),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _transport,
                        decoration: const InputDecoration(labelText: 'Ulaşım'),
                        items: const ['Araç', 'Yürüyüş', 'Bisiklet']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _transport = value ?? _transport),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Molalar', style: _sectionStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.restaurant_rounded, size: 17),
                      label: const Text('Yerel lezzet'),
                      selected: _addFood,
                      onSelected: (value) => setState(() => _addFood = value),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.local_cafe_rounded, size: 17),
                      label: const Text('Kahve'),
                      selected: _addCafe,
                      onSelected: (value) => setState(() => _addCafe = value),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.breakfast_dining_rounded, size: 17),
                      label: const Text('Kahvaltı'),
                      selected: _addBreakfast,
                      onSelected: (value) =>
                          setState(() => _addBreakfast = value),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.cake_outlined, size: 17),
                      label: const Text('Tatlı'),
                      selected: _addDessert,
                      onSelected: (value) =>
                          setState(() => _addDessert = value),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.hotel_rounded, size: 17),
                      label: const Text('Konaklama'),
                      selected: _addHotel,
                      onSelected: (value) => setState(() => _addHotel = value),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _city == null || _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _generating ? 'Rota hesaplanıyor…' : 'Planımı Hazırla',
                    ),
                  ),
                ),
                if (_generated.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  if (_intelligence != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.subtleGradient,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderAccent),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _PlanMetric(
                            icon: Icons.route_rounded,
                            text:
                                '${_intelligence!.distanceKm.toStringAsFixed(1)} km',
                          ),
                          _PlanMetric(
                            icon: Icons.schedule_rounded,
                            text: '${_intelligence!.travelMinutes} dk yol',
                          ),
                          _PlanMetric(
                            icon: Icons.payments_outlined,
                            text: '≈ $_estimatedBudget TL',
                          ),
                          if (_intelligence!.weatherSummary.isNotEmpty)
                            _PlanMetric(
                              icon: Icons.cloud_outlined,
                              text: _intelligence!.weatherSummary,
                            ),
                        ],
                      ),
                    ),
                  const Text('Önerilen rota', style: _sectionStyle),
                  const SizedBox(height: 8),
                  ...List.generate(_generated.length, (index) {
                    final spot = _generated[index];
                    return Card(
                      child: ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: SpotImage(
                            spot: spot,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        title: Text(
                          '${index + 1}. ${spot.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${spot.category} • ${spot.bestTime}'),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RoutePlannerScreen(initialSpots: _generated),
                      ),
                    ),
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('Rotayı Haritada Aç'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _shareGenerated,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Planı Adıyla Paylaş'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            widget.inviteAfterSave
                                ? Icons.group_add_rounded
                                : Icons.bookmark_add_rounded,
                          ),
                    label: Text(
                      widget.inviteAfterSave
                          ? 'Kaydet ve Arkadaşlarını Seç'
                          : 'Planı Kaydet',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

const _sectionStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w900);

class _PlanMetric extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PlanMetric({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.cyan),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}
