import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
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

  void _generate() {
    final city = _city;
    if (city == null) return;
    final count = _duration <= 3
        ? 3
        : _duration <= 5
        ? 5
        : 7;
    final candidates = _allSpots
        .where((spot) => _normalize(spot.city) == _normalize(city))
        .toList()
      ..sort((a, b) => _score(b).compareTo(_score(a)));
    final selected = _orderNearby(candidates.take(count).toList());
    setState(() {
      _generated = selected;
      if (_title.text.trim().isEmpty) _title.text = '$city gezi planı';
    });
    if (selected.isEmpty) _message('$city için uygun rota bulunamadı.');
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
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _city == null ? null : _generate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Planımı Hazırla'),
                  ),
                ),
                if (_generated.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: _title,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Plan adı',
                      prefixIcon: Icon(Icons.edit_outlined),
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
