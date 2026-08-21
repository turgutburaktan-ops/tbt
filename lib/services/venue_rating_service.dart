import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'content_moderation_service.dart';

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

class VenueReview {
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final int helpfulCount;
  final bool mine;
  final bool helpfulByMe;
  final DateTime updatedAt;

  const VenueReview({
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.helpfulCount,
    required this.mine,
    required this.helpfulByMe,
    required this.updatedAt,
  });
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

  Future<VenueRatingSummary> summary(String category, String venueId) async {
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

  Stream<VenueRatingSummary> watchSummary(String category, String venueId) =>
      _venueRef(category, venueId).snapshots().asyncMap((_) => summary(category, venueId));

  Stream<List<VenueReview>> watchReviews(
    String category,
    String venueId, {
    int limit = 80,
  }) {
    final uid = _auth.currentUser?.uid;
    return _venueRef(category, venueId)
        .collection('ratings')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final result = <VenueReview>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final comment = (data['comment'] ?? '').toString().trim();
        if (comment.isEmpty) continue;
        final helpfulByMe = uid == null
            ? false
            : (await doc.reference.collection('helpful').doc(uid).get()).exists;
        result.add(VenueReview(
          userId: doc.id,
          userName: (data['userName'] ?? '').toString().trim().isEmpty
              ? 'Kullanıcı'
              : (data['userName'] ?? '').toString(),
          rating: ((data['rating'] as num?)?.toInt() ?? 1).clamp(1, 5),
          comment: comment,
          helpfulCount: ((data['helpfulCount'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31),
          mine: uid != null && doc.id == uid,
          helpfulByMe: helpfulByMe,
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }
      return result;
    });
  }

  Future<void> rate({
    required String category,
    required String venueId,
    required String venueName,
    required int rating,
  }) => submitReview(
        category: category,
        venueId: venueId,
        venueName: venueName,
        rating: rating,
        preserveExistingComment: true,
      );

  Future<void> submitReview({
    required String category,
    required String venueId,
    required String venueName,
    required int rating,
    String? comment,
    bool preserveExistingComment = false,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('Puan 1 ile 5 arasında olmalı.');
    }
    final user = _auth.currentUser;
    if (user == null) throw Exception('Değerlendirme yapmak için giriş yapmalısın.');

    final cleanComment = comment?.trim();
    if (cleanComment != null) {
      if (cleanComment.length > 700) {
        throw Exception('Yorum en fazla 700 karakter olabilir.');
      }
      ContentModerationService.instance.enforce(cleanComment);
    }

    final venueRef = _venueRef(category, venueId);
    final ratingRef = venueRef.collection('ratings').doc(user.uid);

    await _firestore.runTransaction((tx) async {
      final venueSnap = await tx.get(venueRef);
      final ratingSnap = await tx.get(ratingRef);
      final venueData = venueSnap.data() ?? const <String, dynamic>{};
      final ratingData = ratingSnap.data() ?? const <String, dynamic>{};
      var count = ((venueData['ratingCount'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31);
      var total = ((venueData['ratingTotal'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31);
      final previous = (ratingData['rating'] as num?)?.toInt();

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

      final payload = <String, dynamic>{
        'userId': user.uid,
        'userName': user.displayName ?? '',
        'rating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (cleanComment != null) {
        payload['comment'] = cleanComment;
        payload['moderationStatus'] = 'published';
      } else if (!preserveExistingComment) {
        payload['comment'] = '';
      }
      if (!ratingSnap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['helpfulCount'] = 0;
      }
      tx.set(ratingRef, payload, SetOptions(merge: true));
    });
  }

  Future<void> deleteMyReview({
    required String category,
    required String venueId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    final venueRef = _venueRef(category, venueId);
    final ratingRef = venueRef.collection('ratings').doc(user.uid);
    await _firestore.runTransaction((tx) async {
      final venueSnap = await tx.get(venueRef);
      final ratingSnap = await tx.get(ratingRef);
      if (!ratingSnap.exists) return;
      final venueData = venueSnap.data() ?? const <String, dynamic>{};
      final oldRating = (ratingSnap.data()?['rating'] as num?)?.toInt() ?? 0;
      var count = ((venueData['ratingCount'] as num?)?.toInt() ?? 0) - 1;
      var total = ((venueData['ratingTotal'] as num?)?.toInt() ?? 0) - oldRating;
      count = count.clamp(0, 1 << 31);
      total = total.clamp(0, 1 << 31);
      tx.set(venueRef, {
        'ratingCount': count,
        'ratingTotal': total,
        'ratingAverage': count == 0 ? 0.0 : total / count,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.delete(ratingRef);
    });
  }

  Future<void> toggleHelpful({
    required String category,
    required String venueId,
    required String reviewUserId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Faydalı oyu için giriş yapmalısın.');
    if (reviewUserId == user.uid) throw Exception('Kendi yorumuna oy veremezsin.');
    final reviewRef = _venueRef(category, venueId).collection('ratings').doc(reviewUserId);
    final helpfulRef = reviewRef.collection('helpful').doc(user.uid);
    await _firestore.runTransaction((tx) async {
      final reviewSnap = await tx.get(reviewRef);
      final helpfulSnap = await tx.get(helpfulRef);
      if (!reviewSnap.exists) return;
      var count = ((reviewSnap.data()?['helpfulCount'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31);
      if (helpfulSnap.exists) {
        count = (count - 1).clamp(0, 1 << 31);
        tx.delete(helpfulRef);
      } else {
        count += 1;
        tx.set(helpfulRef, {
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(reviewRef, {'helpfulCount': count});
    });
  }

  Future<void> reportReview({
    required String category,
    required String venueId,
    required String reviewUserId,
    String reason = 'uygunsuz_icerik',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Şikâyet etmek için giriş yapmalısın.');
    if (reviewUserId == user.uid) throw Exception('Kendi yorumunu şikâyet edemezsin.');
    final reviewRef = _venueRef(category, venueId).collection('ratings').doc(reviewUserId);
    await reviewRef.collection('reports').doc(user.uid).set({
      'reporterId': user.uid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('review_reports').add({
      'venueKey': venueKey(category, venueId),
      'category': category,
      'venueId': venueId,
      'reviewUserId': reviewUserId,
      'reporterId': user.uid,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
