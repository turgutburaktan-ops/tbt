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
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _items(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  Stream<List<AppNotificationItem>> watchMine({int limit = 80}) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <AppNotificationItem>[]);
      return _items(user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map(AppNotificationItem.fromDocument)
              .toList(growable: false));
    });
  }

  Stream<int> unreadCount() => watchMine().map(
        (items) => items.where((item) => !item.read).length,
      );

  Stream<int> unreadMessageCount() => watchMine().map(
        (items) => items
            .where((item) => !item.read && item.type.toLowerCase() == 'message')
            .length,
      );

  Future<void> notifyUser({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? sourceId,
    String? actorId,
  }) async {
    if (userId.trim().isEmpty) return;
    final current = _auth.currentUser;
    if (current != null && current.uid == userId) return;

    await _items(userId).add({
      'type': type.trim().isEmpty ? 'general' : type.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'sourceId': sourceId,
      'actorId': actorId ?? current?.uid,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> notifyUsers({
    required Iterable<String> userIds,
    required String type,
    required String title,
    required String body,
    String? sourceId,
    String? actorId,
  }) async {
    final unique =
        userIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (unique.isEmpty) return;

    await Future.wait(unique.map((userId) => notifyUser(
          userId: userId,
          type: type,
          title: title,
          body: body,
          sourceId: sourceId,
          actorId: actorId,
        )));
  }

  Future<void> markRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null || notificationId.trim().isEmpty) return;
    await _items(user.uid).doc(notificationId).set({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllRead() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot =
        await _items(user.uid).where('read', isEqualTo: false).limit(100).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(
          doc.reference,
          {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }
}
