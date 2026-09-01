import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/business_service.dart';
import '../theme/app_theme.dart';

class BusinessHoursScreen extends StatefulWidget {
  final String category;
  final String venueId;
  const BusinessHoursScreen({
    super.key,
    required this.category,
    required this.venueId,
  });
  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  static const _days = <String, String>{
    'mon': 'Pazartesi',
    'tue': 'Salı',
    'wed': 'Çarşamba',
    'thu': 'Perşembe',
    'fri': 'Cuma',
    'sat': 'Cumartesi',
    'sun': 'Pazar',
  };
  final Map<String, bool> _closed = {};
  final Map<String, TimeOfDay> _open = {};
  final Map<String, TimeOfDay> _close = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final d in _days.keys) {
      _closed[d] = false;
      _open[d] = const TimeOfDay(hour: 9, minute: 0);
      _close[d] = const TimeOfDay(hour: 22, minute: 0);
    }
    _load();
  }

  TimeOfDay _parse(String value, TimeOfDay fallback) {
    final p = value.split(':');
    if (p.length != 2) return fallback;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    return h == null || m == null ? fallback : TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final key = BusinessService.instance.venueKey(
      widget.category,
      widget.venueId,
    );
    final snap = await FirebaseFirestore.instance
        .collection('business_venues')
        .doc(key)
        .get();
    final weekly = Map<String, dynamic>.from(
      (snap.data()?['weeklyHours'] as Map?) ?? const {},
    );
    for (final d in _days.keys) {
      final row = Map<String, dynamic>.from((weekly[d] as Map?) ?? const {});
      if (row.isEmpty) continue;
      _closed[d] = row['closed'] == true;
      _open[d] = _parse((row['open'] ?? '').toString(), _open[d]!);
      _close[d] = _parse((row['close'] ?? '').toString(), _close[d]!);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick(String day, bool opening) async {
    final current = opening ? _open[day]! : _close[day]!;
    final value = await showTimePicker(context: context, initialTime: current);
    if (value != null)
      setState(() => opening ? _open[day] = value : _close[day] = value);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{};
      for (final d in _days.keys) {
        data[d] = {
          'closed': _closed[d] == true,
          'open': _fmt(_open[d]!),
          'close': _fmt(_close[d]!),
        };
      }
      await BusinessService.instance.updateWeeklyHours(
        category: widget.category,
        venueId: widget.venueId,
        weeklyHours: data,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çalışma saatleri güncellendi.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Çalışma Saatleri')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              const Text(
                'Haftalık program',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Profilde Açık/Kapalı durumu bu saatlere göre otomatik hesaplanır.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 14),
              ..._days.entries.map(
                (e) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(_closed[e.key] == true ? 'Kapalı' : 'Açık', style: TextStyle(color: _closed[e.key] == true ? Colors.white54 : AppColors.cyan, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Switch(
                              value: _closed[e.key] != true,
                              onChanged: (v) => setState(() => _closed[e.key] = !v),
                            ),
                          ],
                        ),
                        if (_closed[e.key] != true)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pick(e.key, true),
                                  child: Text('Açılış\n${_fmt(_open[e.key]!)}', textAlign: TextAlign.center),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pick(e.key, false),
                                  child: Text(
                                    'Kapanış\n${_fmt(_close[e.key]!)}',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Kaydediliyor…' : 'Saatleri Kaydet'),
        ),
      ),
    ),
  );
}
