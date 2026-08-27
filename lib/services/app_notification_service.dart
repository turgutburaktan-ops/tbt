import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? sourceId;
  final String? actorId;
  final bool read;
  final DateTime? createdAt;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.sourceId,
    this.actorId,
    required this.read,
    this.createdAt,
  });

  factory AppNotificationItem.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    return AppNotificationItem(
      id: doc.id,
      type: (data['type'] ?? 'general').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      sourceId: data['sourceId']?.toString(),
      actorId: data['actorId']?.toString(),
      read: data['read'] == true,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class AppNotificationService {
  AppNotificationService._() {
    _sharedMine = _ReplayLatest<List<AppNotificationItem>>(
      _buildMineStream(80),
    );
  }

  static final AppNotificationService instance = AppNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final _ReplayLatest<List<AppNotificationItem>> _sharedMine;

  CollectionReference<Map<String, dynamic>> _items(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  Stream<List<AppNotificationItem>> _buildMineStream(int limit) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <AppNotificationItem>[]);
      return _items(user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(AppNotificationItem.fromDocument)
                .toList(growable: false),
          );
    });
  }

  Stream<List<AppNotificationItem>> watchMine({int limit = 80}) {
    if (limit == 80) return _sharedMine.stream;
    return _buildMineStream(limit);
  }

  Stream<int> unreadCount() => _sharedMine.stream
      .map((items) => items.where((item) => !item.read).length)
      .distinct();

  Stream<int> unreadMessageCount() => _sharedMine.stream
      .map(
        (items) => items
            .where(
              (item) => !item.read && item.type.toLowerCase() == 'message',
            )
            .length,
      )
      .distinct();

  Future<void> notifyUser({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? sourceId,
    String? actorId,
  }) async {
    final target = userId.trim();
    if (target.isEmpty) return;
    final current = _auth.currentUser;
    if (current != null && current.uid == target) return;

    await _items(target).add({
      'type': type.trim().isEmpty ? 'general' : type.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'sourceId': sourceId,
      'actorId': actorId ?? current?.uid,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 6));
  }

  Future<void> notifyUsers({
    required Iterable<String> userIds,
    required String type,
    required String title,
    required String body,
    String? sourceId,
    String? actorId,
  }) async {
    final unique = userIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (unique.isEmpty) return;

    const chunkSize = 20;
    for (var start = 0; start < unique.length; start += chunkSize) {
      final end = (start + chunkSize < unique.length)
          ? start + chunkSize
          : unique.length;
      final chunk = unique.sublist(start, end);
      await Future.wait(
        chunk.map((userId) async {
          try {
            await notifyUser(
              userId: userId,
              type: type,
              title: title,
              body: body,
              sourceId: sourceId,
              actorId: actorId,
            );
          } catch (_) {}
        }),
      );
    }
  }

  Future<void> notifyMeOnce({
    required String dedupeKey,
    required String type,
    required String title,
    required String body,
    String? sourceId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || dedupeKey.trim().isEmpty) return;
    final safeKey = dedupeKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final ref = _items(user.uid).doc('smart_$safeKey');
    final existing = await ref.get().timeout(const Duration(seconds: 5));
    if (existing.exists) return;
    await ref.set({
      'type': type,
      'title': title.trim(),
      'body': body.trim(),
      'sourceId': sourceId,
      'actorId': null,
      'read': false,
      'smart': true,
      'dedupeKey': dedupeKey,
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 6));
  }

  Future<void> refreshCampusDigest() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final university = (profile.data()?['university'] ?? '')
          .toString()
          .trim();
      if (university.isEmpty) return;

      final communities = await _firestore
          .collection('communities')
          .where('university', isEqualTo: university)
          .limit(80)
          .get()
          .timeout(const Duration(seconds: 6));
      final ids = communities.docs.map((d) => d.id).toSet();
      if (ids.isEmpty) return;

      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final events = await _firestore
          .collection('social_events')
          .where('visibility', isEqualTo: 'public')
          .limit(120)
          .get()
          .timeout(const Duration(seconds: 6));

      final tonight = events.docs.where((doc) {
        final d = doc.data();
        if (!ids.contains((d['communityId'] ?? '').toString())) return false;
        if ((d['status'] ?? 'open').toString() != 'open') return false;
        final raw = d['startsAt'];
        if (raw is! Timestamp) return false;
        final start = raw.toDate();
        return start.isAfter(now) && !start.isAfter(endOfDay);
      }).toList();

      if (tonight.isEmpty) return;
      final dayKey =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final firstId = tonight.first.id;
      await notifyMeOnce(
        dedupeKey: 'campus_evening_${university.hashCode}_$dayKey',
        type: 'campus_digest',
        title: 'Bu akşam kampüsünde ${tonight.length} etkinlik var',
        body: tonight.length == 1
            ? (tonight.first.data()['title'] ?? 'Etkinlik').toString()
            : '${(tonight.first.data()['title'] ?? 'Etkinlik')} ve ${tonight.length - 1} etkinlik daha',
        sourceId: firstId,
      );
    } catch (_) {}
  }

  Future<void> markRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null || notificationId.trim().isEmpty) return;
    await _items(user.uid).doc(notificationId).set({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
  }

  Future<void> markAllRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _items(user.uid).limit(400);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snapshot = await query.get().timeout(const Duration(seconds: 8));
      if (snapshot.docs.isEmpty) return;

      final unreadDocs = snapshot.docs
          .where((doc) => doc.data()['read'] != true)
          .toList(growable: false);
      if (unreadDocs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in unreadDocs) {
          batch.set(doc.reference, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit().timeout(const Duration(seconds: 8));
      }

      if (snapshot.docs.length < 400) return;
      cursor = snapshot.docs.last;
    }
  }
}

class _ReplayLatest<T> {
  final StreamController<T> _controller = StreamController<T>.broadcast();
  late final StreamSubscription<T> _sourceSubscription;
  T? _lastValue;
  bool _hasValue = false;

  _ReplayLatest(Stream<T> source) {
    _sourceSubscription = source.listen(
      (value) {
        _lastValue = value;
        _hasValue = true;
        _controller.add(value);
      },
      onError: _controller.addError,
    );
  }

  Stream<T> get stream => Stream<T>.multi((subscriber) {
    final subscription = _controller.stream.listen(
      subscriber.add,
      onError: subscriber.addError,
    );
    if (_hasValue) subscriber.add(_lastValue as T);
    subscriber.onCancel = subscription.cancel;
  });
}
