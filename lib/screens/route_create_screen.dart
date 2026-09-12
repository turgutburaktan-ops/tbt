import '../models/photo_spot.dart';
import '../services/spot_repository.dart';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'route_planner_screen.dart';

class RouteCreateScreen extends StatefulWidget {
  const RouteCreateScreen({super.key});
  @override
  State<RouteCreateScreen> createState() => _RouteCreateScreenState();
}

class _RouteCreateScreenState extends State<RouteCreateScreen> {
  final _city = TextEditingController();
  bool _suggesting = false;
  int _hours = 3;
  String _company = 'Tek başıma';
  String _transport = 'Araç';
  String _budget = 'Orta';
  final _interests = <String>{};
  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    if (_city.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şehir veya bölgeyi yaz.')));
      return;
    }
    setState(() => _suggesting = true);
    try {
      final spots = await SpotRepository.instance.search(
        _city.text.trim(),
        limit: 200,
      );
      if (spots.isEmpty)
        throw Exception(
          'Bu bölgede hazır nokta yok. Haritadan kendi duraklarını ekleyebilirsin.',
        );
      final candidates = spots.toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      final alternatives = <List<PhotoSpot>>[];
      for (final first in candidates.take(3)) {
        final rest =
            candidates
                .where(
                  (s) =>
                      s.id != first.id &&
                      Geolocator.distanceBetween(
                            first.latitude,
                            first.longitude,
                            s.latitude,
                            s.longitude,
                          ) <
                          8000,
                )
                .toList()
              ..sort(
                (a, b) =>
                    Geolocator.distanceBetween(
                      first.latitude,
                      first.longitude,
                      a.latitude,
                      a.longitude,
                    ).compareTo(
                      Geolocator.distanceBetween(
                        first.latitude,
                        first.longitude,
                        b.latitude,
                        b.longitude,
                      ),
                    ),
              );
        alternatives.add([first, ...rest.take((_hours - 1).clamp(0, 3))]);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutePlannerScreen(
            city: _city.text.trim(),
            durationHours: _hours,
            budget: _budget,
            interests: _interests.toList(),
            initialTransport: _transport,
            initialUseCurrentLocation: false,
            initialSpots: alternatives.first,
            alternatives: alternatives.skip(1).toList(),
            inviteFriends: _company == 'Arkadaşlarımla',
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Rota oluştur')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _city,
          decoration: const InputDecoration(
            labelText: 'Nereye?',
            hintText: 'Şehir veya bölge',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _hours,
          decoration: const InputDecoration(labelText: 'Ne kadar süre?'),
          items: [1, 2, 3, 4, 6, 8, 12, 24]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n saat')))
              .toList(),
          onChanged: (v) => setState(() => _hours = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _company,
          decoration: const InputDecoration(labelText: 'Kimlerle?'),
          items: [
            'Tek başıma',
            'Arkadaşlarımla',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => _company = v!),
        ),
        if (_company == 'Arkadaşlarımla')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Rotanı kaydettikten sonra arkadaşlarını seçip davet edebilirsin.',
            ),
          ),
        ExpansionTile(
          title: const Text('Diğer tercihler'),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _transport,
              decoration: const InputDecoration(labelText: 'Ulaşım'),
              items: [
                'Araç',
                'Yürüyüş',
                'Bisiklet',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _transport = v!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _budget,
              decoration: const InputDecoration(labelText: 'Bütçe'),
              items: [
                'Düşük',
                'Orta',
                'Yüksek',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _budget = v!),
            ),
            Wrap(
              spacing: 8,
              children: ['Doğa', 'Tarih', 'Yeme içme', 'Fotoğraf']
                  .map(
                    (v) => FilterChip(
                      label: Text(v),
                      selected: _interests.contains(v),
                      onSelected: (yes) => setState(
                        () => yes ? _interests.add(v) : _interests.remove(v),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _suggesting ? null : _suggest,
          child: Text(_suggesting ? 'Rota hazırlanıyor…' : 'Bana rota öner'),
        ),
        FilledButton(
          onPressed: () {
            if (_city.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Şehir veya bölgeyi yaz.')),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RoutePlannerScreen(
                  initialUseCurrentLocation: false,
                  initialTransport: _transport,
                  city: _city.text.trim(),
                  durationHours: _hours,
                  budget: _budget,
                  interests: _interests.toList(),
                  inviteFriends: _company == 'Arkadaşlarımla',
                ),
              ),
            );
          },
          child: const Text('Durakları seç'),
        ),
      ],
    ),
  );
}
