import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppObservabilityService {
  AppObservabilityService._();
  static final instance = AppObservabilityService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic> _flags = const {};

  bool flag(String key, {bool fallback = true}) {
    final value = _flags[key];
    return value is bool ? value : fallback;
  }

  Future<void> initialize() async {
    await refreshFlags();
  }

  Future<void> refreshFlags() async {
    try {
      final doc = await _db.collection('app_config').doc('public').get();
      _flags = doc.data()?['featureFlags'] is Map
          ? Map<String, dynamic>.from(doc.data()!['featureFlags'] as Map)
          : const {};
    } catch (_) {
      _flags = const {};
    }
  }

  Future<void> logEvent(String name, [Map<String, Object?> params = const {}]) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final user = await _db.collection('users').doc(uid).get();
      final privacy = user.data()?['privacy'];
      if (privacy is Map && privacy['analyticsConsent'] == false) return;
      await _db.collection('analytics_events').add({
        'name': name,
        'uid': uid,
        'params': params,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> recordError(Object error, StackTrace stack, {String context = ''}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await _db.collection('app_errors').add({
        'uid': uid,
        'context': context,
        'error': error.toString().substring(0, error.toString().length.clamp(0, 1200)),
        'stack': stack.toString().substring(0, stack.toString().length.clamp(0, 5000)),
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
