import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VenueRatingSummary {
  final double average;
  final int count;
  final int? mine;

  const VenueRatingSummary({
    required this.average,
    required this.count,
    this.mine,
  });

  static const empty = VenueRatingSummary(average: 0, count: 0);
}

class VenueRatingService {
  VenueRatingService._();
  static final instance = VenueRatingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String venueKey(String category, String venueId) {
    final raw = '${category}_$venueId';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  DocumentReference<Map<String, dynamic>> _venueRef(
    String category,
    String venueId,
  ) => _firestore.collection('venue_ratings').doc(venueKey(category, venueId));

  Future<VenueRatingSummary> summary(
    String category,
    String venueId,
  ) async {
    final ref = _venueRef(category, venueId);
    final doc = await ref.get();
    final data = doc.data() ?? const <String, dynamic>{};
    final count = ((data['ratingCount'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31);
    final average = ((data['ratingAverage'] as num?)?.toDouble() ?? 0)
        .clamp(0, 5)
        .toDouble();
    int? mine;
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final mineDoc = await ref.collection('ratings').doc(uid).get();
      mine = (mineDoc.data()?['rating'] as num?)?.toInt();
    }
    return VenueRatingSummary(average: average, count: count, mine: mine);
  }

  Stream<VenueRatingSummary> watchSummary(
    String category,
    String venueId,
  ) {
    return _venueRef(category, venueId).snapshots().asyncMap((_) {
      return summary(category, venueId);
    });
  }

  Future<void> rate({
    required String category,
    required String venueId,
    required String venueName,
    required int rating,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('Puan 1 ile 5 arasında olmalı.');
    }
    final user = _auth.currentUser;
    if (user == null) throw Exception('Puan vermek için giriş yapmalısın.');

    final venueRef = _venueRef(category, venueId);
    final ratingRef = venueRef.collection('ratings').doc(user.uid);

    await _firestore.runTransaction((tx) async {
      final venueSnap = await tx.get(venueRef);
      final ratingSnap = await tx.get(ratingRef);
      final venueData = venueSnap.data() ?? const <String, dynamic>{};
      var count = ((venueData['ratingCount'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31);
      var total = ((venueData['ratingTotal'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31);
      final previous = (ratingSnap.data()?['rating'] as num?)?.toInt();

      if (previous == null) {
        count += 1;
        total += rating;
      } else {
        total = (total - previous + rating).clamp(0, 1 << 31);
      }
      final average = count == 0 ? 0.0 : total / count;

      tx.set(venueRef, {
        'venueId': venueId,
        'venueName': venueName,
        'category': category,
        'ratingCount': count,
        'ratingTotal': total,
        'ratingAverage': average,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(ratingRef, {
        'userId': user.uid,
        'userName': user.displayName ?? '',
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
