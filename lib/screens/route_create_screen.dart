import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import '../services/travel_plan_service.dart';
import '../services/user_facing_error.dart';
import '../theme/app_theme.dart';
import '../widgets/route_stop_picker.dart';
import 'travel_plan_detail_screen.dart';
import 'routes_hub_screen.dart';

class RouteCreateScreen extends StatefulWidget {
  const RouteCreateScreen({super.key, this.initialStops = const []});
  final List<PhotoSpot> initialStops;
  @override
  State<RouteCreateScreen> createState() => _RouteCreateScreenState();
}

class _RouteCreateScreenState extends State<RouteCreateScreen> {
  final _city = TextEditingController();
  late final List<PhotoSpot> _stops = [...widget.initialStops];
  String _transport = 'Araç';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    if (_stops.isNotEmpty) _city.text = _stops.first.city;
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final spot = await showModalBottomSheet<PhotoSpot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RouteStopPicker(city: _city.text.trim(), stops: _stops),
    );
    if (spot != null && mounted)
      setState(() {
        if (!_stops.any((s) => s.id == spot.id)) _stops.add(spot);
        if (_city.text.trim().isEmpty) _city.text = spot.city;
      });
  }

  Future<void> _suggest() => _act(() async {
    if (_city.text.trim().isEmpty)
      throw Exception('Önce şehir veya bölge yaz.');
    final all = await SpotRepository.instance.search(
      _city.text.trim(),
      limit: 100,
    );
    if (all.isEmpty)
      throw Exception(
        'Burada önerilecek durak bulunamadı. Durak ekleyebilirsin.',
      );
    final sorted = all.toList()..sort((a, b) => b.rating.compareTo(a.rating));
    if (mounted)
      setState(() {
        for (final s in sorted.take(4)) {
          if (_stops.length < 12 && !_stops.any((p) => p.id == s.id))
            _stops.add(s);
        }
      });
  });
  Future<void> _save() => _act(() async {
    final city = _city.text.trim().isEmpty
        ? _stops.first.city
        : _city.text.trim();
    final id = await TravelPlanService.instance.create(
      title: '$city gezisi',
      city: city,
      durationHours: 3,
      budget: 'Orta',
      transport: _transport,
      interests: [],
      spots: _stops,
    );
    final plan = await TravelPlanService.instance.read(id);
    if (mounted)
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TravelPlanDetailScreen(plan: plan)),
      );
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF07080B),
    appBar: AppBar(title: const Text('Rota oluştur')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _busy || _stops.isEmpty ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.all(17),
          ),
          child: Text(_busy ? 'Hazırlanıyor…' : 'Rotayı oluştur'),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Nereye gidiyoruz?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _city,
          decoration: const InputDecoration(
            hintText: 'Şehir veya bölge ara',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in ['Araç', 'Yürüyüş', 'Bisiklet'])
              ChoiceChip(
                avatar: Icon(routeTransportIcon(mode), size: 18),
                label: Text(mode),
                selected: _transport == mode,
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _transport = mode),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Durakların',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _busy ? _noAction : _suggest,
              child: const Text('Bana rota öner'),
            ),
          ],
        ),
        if (_stops.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Gezilecek yer veya mekân ekleyerek başla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _stops.length,
          onReorder: (a, b) {
            if (_busy) return;
            setState(() {
              if (b > a) b--;
              _stops.insert(b, _stops.removeAt(a));
            });
          },
          itemBuilder: (_, i) => Card(
            key: ValueKey(_stops[i].id),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.cyan,
                foregroundColor: Colors.black,
                child: Text('${i + 1}'),
              ),
              title: Text(_stops[i].name),
              subtitle: Text(_stops[i].category),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _stops.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy || _stops.length >= 12 ? null : _add,
          icon: const Icon(Icons.add),
          label: const Text('Durak ekle'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tarih ve arkadaşlarını rotayı oluşturduktan sonra ekleyebilirsin.',
          style: TextStyle(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
  void _noAction() {}
}
