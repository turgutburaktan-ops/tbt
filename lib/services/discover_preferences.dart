import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'discover_ranker.dart';

/// Bounded, account-scoped device history. No production writes or broad reads.
class DiscoverPreferences {
  DiscoverPreferences._();
  static final instance = DiscoverPreferences._();
  String? _account;
  Future<void>? _loading;
  final Map<String, int> _views = {};
  final Map<String, double> interests = {};
  final Map<String, String> _topics = {};
  final Set<String> _signals = {};
  Timer? _saveTimer;
  Set<String> get seen => _views.keys.toSet();
  String get _current => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  Future<void> load() {
    final account = _current;
    if (_account == account && _loading != null) return _loading!;
    _account = account;
    _views.clear();
    interests.clear();
    _topics.clear();
    _signals.clear();
    _saveTimer?.cancel();
    return _loading = _read(account);
  }

  Future<void> _read(String account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('discover_history_v1_$account');
      if (_account != account || raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 14))
          .millisecondsSinceEpoch;
      for (final e in (data['views'] as Map? ?? {}).entries) {
        if (e.value is int && e.value > cutoff)
          _views[e.key.toString()] = e.value;
      }
      for (final e in (data['interests'] as Map? ?? {}).entries) {
        if (e.value is num)
          interests[e.key.toString()] = (e.value as num).toDouble().clamp(
            0,
            30,
          );
      }
    } catch (_) {
      /* Recommendations must not block browsing. */
    }
  }

  void register(String id, Map<String, dynamic> data) {
    if (_account == _current) _topics[id] = discoverTopic(data);
  }

  void viewed(String id) {
    if (_account != _current) return;
    _views.remove(id);
    _views[id] = DateTime.now().millisecondsSinceEpoch;
    while (_views.length > 1000) {
      _views.remove(_views.keys.first);
    }
    _scheduleSave();
  }

  void signal(String id, String action, double weight) {
    if (_account != _current ||
        !_topics.containsKey(id) ||
        !_signals.add('$action:$id'))
      return;
    final topic = _topics[id]!;
    interests[topic] = ((interests[topic] ?? 0) + weight).clamp(0, 30);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    final account = _account;
    _saveTimer = Timer(const Duration(milliseconds: 400), () async {
      final value = jsonEncode({'views': _views, 'interests': interests});
      try {
        final prefs = await SharedPreferences.getInstance();
        if (account == _account)
          await prefs.setString('discover_history_v1_$account', value);
      } catch (_) {}
    });
  }
}
