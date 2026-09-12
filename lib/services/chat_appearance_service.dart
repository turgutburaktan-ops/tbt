import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChatBackground {
  midnight('Gece mavisi', Color(0xFF0B1426)),
  charcoal('Antrasit', Color(0xFF191D24)),
  black('Siyah', Color(0xFF080B10)),
  forest('Koyu yeşil', Color(0xFF0C231F)),
  purple('Koyu mor', Color(0xFF211830)),
  petrol('Petrol mavisi', Color(0xFF0B252E));

  const ChatBackground(this.label, this.color);
  final String label;
  final Color color;

  static ChatBackground fromName(String? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => midnight,
  );
}

/// Cosmetic preferences are local and scoped to the signed-in account.
class ChatAppearanceService extends ChangeNotifier {
  ChatAppearanceService({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  static final instance = ChatAppearanceService();
  final Future<SharedPreferences> Function() _preferences;
  StreamSubscription<User?>? _authSubscription;
  Future<void>? _loading;
  String? _userId;
  int _generation = 0;
  ChatBackground _background = ChatBackground.midnight;
  ChatBackground get background => _background;
  String? get userId => _userId;
  Future<void> get ready => _loading ?? Future<void>.value();

  void start() {
    if (_authSubscription != null) return;
    unawaited(loadForUser(FirebaseAuth.instance.currentUser?.uid));
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => unawaited(loadForUser(user?.uid)),
    );
  }

  Future<void> loadForUser(String? userId) {
    if (_loading != null && userId == _userId) return _loading!;
    _userId = userId;
    final generation = ++_generation;
    _background = ChatBackground.midnight;
    notifyListeners();
    return _loading = _load(userId, generation);
  }

  Future<void> _load(String? userId, int generation) async {
    if (userId == null) return;
    try {
      final prefs = await _preferences();
      final selected = ChatBackground.fromName(
        prefs.get('chat_background_v1_$userId') is String
            ? prefs.getString('chat_background_v1_$userId')
            : null,
      );
      if (generation != _generation) return;
      _background = selected;
      notifyListeners();
    } catch (_) {
      // A missing/unreadable local preference must never block messaging.
    }
  }

  Future<void> select(ChatBackground selected) async {
    final userId = _userId;
    final generation = _generation;
    if (userId == null) throw StateError('Sign-in required');
    await _loading;
    if (generation != _generation) throw StateError('Account changed');
    final prefs = await _preferences();
    if (generation != _generation) throw StateError('Account changed');
    if (!await prefs.setString('chat_background_v1_$userId', selected.name)) {
      throw StateError('Preference could not be saved');
    }
    if (generation != _generation) throw StateError('Account changed');
    _background = selected;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _authSubscription?.cancel();
    super.dispose();
  }
}
