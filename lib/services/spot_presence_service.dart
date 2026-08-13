import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_spot.dart';
import '../models/spot_presence.dart';

class SpotPresenceService {
  SpotPresenceService._();

  static final SpotPresenceService instance = SpotPresenceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String collection = 'spot_presence';
  static const Duration defaultVisibility = Duration(minutes: 90);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authChanges => _auth.authStateChanges();

  Stream<List<SpotPresence>> watchVisibleForSpot(String spotId) {
    return _firestore
        .collection(collection)
        .where('spotId', isEqualTo: spotId)
        .limit(60)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final items = snapshot.docs
          .map(SpotPresence.fromDocument)
          .where((item) {
            final expiry = item.expiresAt;
            return item.visible &&
                item.approximateLocationOnly &&
                (expiry == null || expiry.isAfter(now));
          })
          .toList();

      items.sort((a, b) {
        final aTime = a.checkedInAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.checkedInAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return items;
    });
  }

  Stream<SpotPresence?> watchMineForSpot(String spotId) {
    final user = _auth.currentUser;
    if (user == null) return Stream<SpotPresence?>.value(null);

    return _firestore
        .collection(collection)
        .doc(_presenceId(spotId, user.uid))
        .snapshots()
        .map((document) {
      if (!document.exists) return null;
      final item = SpotPresence.fromDocument(document);
      if (!item.visible || item.isExpired) return null;
      return item;
    });
  }

  Future<bool> isCheckedIn(String spotId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final document = await _firestore
          .collection(collection)
          .doc(_presenceId(spotId, user.uid))
          .get();
      if (!document.exists) return false;
      final item = SpotPresence.fromDocument(document);
      return item.visible && !item.isExpired;
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirebaseMessage(e, readOperation: true));
    }
  }

  Future<void> checkIn(
    PhotoSpot spot, {
    Duration visibility = defaultVisibility,
    String roleLabel = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Burada görünmek için önce giriş yapmalısın.');
    }

    final safeDuration = visibility.inMinutes.clamp(15, 180);
    final now = DateTime.now();
    final expiry = now.add(Duration(minutes: safeDuration));
    final ref = _firestore
        .collection(collection)
        .doc(_presenceId(spot.id, user.uid));

    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : (user.email ?? '').split('@').first.trim().isNotEmpty
            ? (user.email ?? '').split('@').first.trim()
            : 'Fotoğraf tutkunu';

    try {
      await ref.set({
        'id': ref.id,
        'spotId': spot.id,
        'spotName': spot.name,
        'city': spot.city,
        'userId': user.uid,
        'displayName': displayName,
        'photoUrl': user.photoURL ?? '',
        'roleLabel': roleLabel.trim(),
        'visible': true,
        'approximateLocationOnly': true,
        'checkedInAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiry),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirebaseMessage(e));
    }
  }

  Future<void> checkOut(String spotId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Görünürlüğü kapatmak için giriş yapmalısın.');
    }

    final ref = _firestore
        .collection(collection)
        .doc(_presenceId(spotId, user.uid));

    try {
      await ref.set({
        'visible': false,
        'expiresAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirebaseMessage(e));
    }
  }

  String _presenceId(String spotId, String uid) {
    final safeSpotId = spotId.trim().replaceAll('/', '_');
    return '${safeSpotId}_$uid';
  }

  String _friendlyFirebaseMessage(
    FirebaseException error, {
    bool readOperation = false,
  }) {
    switch (error.code) {
      case 'permission-denied':
        return readOperation
            ? 'Buradaki kullanıcıları görüntüleme izni alınamadı. Tekrar giriş yapıp deneyebilirsin.'
            : 'Firestore bu işlem için izin vermedi. Oturumunu yenileyip tekrar dene.';
      case 'unavailable':
        return 'Bağlantı kurulamadı. İnternet bağlantını kontrol edip tekrar dene.';
      case 'unauthenticated':
        return 'Oturum süren dolmuş. Tekrar giriş yapmalısın.';
      case 'deadline-exceeded':
        return 'İşlem zaman aşımına uğradı. Tekrar deneyebilirsin.';
      default:
        return 'Buradayım işlemi tamamlanamadı. Lütfen tekrar dene.';
    }
  }
}
