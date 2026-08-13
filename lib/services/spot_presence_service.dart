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

  Stream<List<SpotPresence>> watchVisibleForSpot(String spotId) {
    return _firestore
        .collection(collection)
        .where('spotId', isEqualTo: spotId)
        .where('visible', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final items = snapshot.docs
          .map(SpotPresence.fromDocument)
          .where((item) {
            final expiry = item.expiresAt;
            return item.approximateLocationOnly &&
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
    final ref = _firestore.collection(collection).doc('${spot.id}_${user.uid}');

    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : 'Fotoğraf tutkunu';

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
  }

  Future<void> checkOut(String spotId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection(collection).doc('${spotId}_${user.uid}');
    await ref.set({
      'visible': false,
      'expiresAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
