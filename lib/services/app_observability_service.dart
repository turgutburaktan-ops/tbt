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
      final data = doc.data();
      final flags = data?['featureFlags'];
      _flags = flags is Map ? Map<String, dynamic>.from(flags) : const {};
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
    final rawError = error.toString();
    final rawStack = stack.toString();
    final safeError = rawError.length > 1200 ? rawError.substring(0, 1200) : rawError;
    final safeStack = rawStack.length > 5000 ? rawStack.substring(0, 5000) : rawStack;
    try {
      await _db.collection('app_errors').add({
        'uid': uid,
        'context': context,
        'error': safeError,
        'stack': safeStack,
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
