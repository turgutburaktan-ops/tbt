import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class OfflineTravelPlansScreen extends StatefulWidget {
  const OfflineTravelPlansScreen({super.key});

  @override
  State<OfflineTravelPlansScreen> createState() =>
      _OfflineTravelPlansScreenState();
}

class _OfflineTravelPlansScreenState extends State<OfflineTravelPlansScreen> {
  List<Map<String, dynamic>> _plans = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList('offline_travel_plan_ids') ?? [];
    final plans = <Map<String, dynamic>>[];
    for (final id in ids) {
      final raw = preferences.getString('offline_travel_plan_$id');
      if (raw == null) continue;
      try {
        plans.add(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    if (mounted) setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  Future<void> _delete(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('offline_travel_plan_$id');
    final ids = preferences.getStringList('offline_travel_plan_ids') ?? [];
    await preferences.setStringList(
      'offline_travel_plan_ids',
      ids.where((item) => item != id).toList(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Çevrimdışı Rotalar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
          ? const Center(child: Text('İndirilmiş rota bulunmuyor.'))
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: _plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final plan = _plans[index];
                final stops = (plan['spotNames'] as List<dynamic>? ?? const [])
                    .map((item) => item.toString())
                    .toList();
                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.offline_pin_rounded),
                    title: Text((plan['title'] ?? 'Gezi planı').toString()),
                    subtitle: Text(
                      '${plan['city'] ?? ''} • ${(plan['distanceKm'] as num?)?.toStringAsFixed(1) ?? '0'} km • ≈ ${plan['estimatedBudget'] ?? 0} TL',
                    ),
                    trailing: IconButton(
                      tooltip: 'İndirilen rotayı sil',
                      onPressed: () => _delete((plan['id'] ?? '').toString()),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    children: [
                      for (var i = 0; i < stops.length; i++)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                          title: Text(stops[i]),
                        ),
                      if ((plan['weatherSummary'] ?? '').toString().isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.cloud_outlined),
                          title: Text((plan['weatherSummary'] ?? '').toString()),
                          subtitle: const Text('İndirme anındaki hava bilgisi'),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
