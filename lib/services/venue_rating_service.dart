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

  CollectionReference<Map<String, dynamic>> _ratings(
    String category,
    String venueId,
  ) => _venueRef(category, venueId).collection('ratings');

  VenueRatingSummary _summaryFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var total = 0;
    var count = 0;
    int? mine;
    final uid = _auth.currentUser?.uid;
    for (final doc in docs) {
      final rating = (doc.data()['rating'] as num?)?.toInt();
      if (rating == null || rating < 1 || rating > 5) continue;
      total += rating;
      count += 1;
      if (uid != null && doc.id == uid) mine = rating;
    }
    return VenueRatingSummary(
      average: count == 0 ? 0 : total / count,
      count: count,
      mine: mine,
    );
  }

  Future<VenueRatingSummary> summary(String category, String venueId) async {
    final snapshot = await _ratings(category, venueId).limit(1000).get();
    return _summaryFromDocs(snapshot.docs);
  }

  Stream<VenueRatingSummary> watchSummary(String category, String venueId) =>
      _ratings(category, venueId)
          .limit(1000)
          .snapshots()
          .map((snapshot) => _summaryFromDocs(snapshot.docs));

  Stream<List<VenueReview>> watchReviews(
    String category,
    String venueId, {
    int limit = 80,
  }) {
    final uid = _auth.currentUser?.uid;
    return _ratings(
      category,
      venueId,
    ).orderBy('updatedAt', descending: true).limit(limit).snapshots().asyncMap((
      snapshot,
    ) async {
      final result = <VenueReview>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final comment = (data['comment'] ?? '').toString().trim();
        if (comment.isEmpty) continue;
        final helpfulCollection = doc.reference.collection('helpful');
        final helpfulByMe = uid == null
            ? false
            : (await helpfulCollection.doc(uid).get()).exists;
        final helpfulAggregate = await helpfulCollection.count().get();
        result.add(
          VenueReview(
            userId: doc.id,
            userName: (data['userName'] ?? '').toString().trim().isEmpty
                ? 'Kullanıcı'
                : (data['userName'] ?? '').toString(),
            rating: ((data['rating'] as num?)?.toInt() ?? 1).clamp(1, 5),
            comment: comment,
            helpfulCount: helpfulAggregate.count ?? 0,
            mine: uid != null && doc.id == uid,
            helpfulByMe: helpfulByMe,
            updatedAt:
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ),
        );
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
    if (user == null) {
      throw Exception('Değerlendirme yapmak için giriş yapmalısın.');
    }

    final cleanComment = comment?.trim();
    if (cleanComment != null) {
      if (cleanComment.length > 700) {
        throw Exception('Yorum en fazla 700 karakter olabilir.');
      }
      ContentModerationService.instance.enforce(cleanComment);
    }

    final ratingRef = _ratings(category, venueId).doc(user.uid);
    final existing = await ratingRef.get();
    final payload = <String, dynamic>{
      'userId': user.uid,
      'userName': user.displayName ?? '',
      'venueId': venueId,
      'venueName': venueName,
      'category': category,
      'rating': rating,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    if (cleanComment != null) {
      payload['comment'] = cleanComment;
      payload['moderationStatus'] = 'published';
    } else if (!preserveExistingComment) {
      payload['comment'] = '';
    }
    await ratingRef.set(payload, SetOptions(merge: true));
  }

  Future<void> deleteMyReview({
    required String category,
    required String venueId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    await _ratings(category, venueId).doc(user.uid).delete();
  }

  Future<void> toggleHelpful({
    required String category,
    required String venueId,
    required String reviewUserId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Faydalı oyu için giriş yapmalısın.');
    if (reviewUserId == user.uid) {
      throw Exception('Kendi yorumuna oy veremezsin.');
    }
    final reviewRef = _ratings(category, venueId).doc(reviewUserId);
    final review = await reviewRef.get();
    if (!review.exists) return;
    final helpfulRef = reviewRef.collection('helpful').doc(user.uid);
    final existing = await helpfulRef.get();
    if (existing.exists) {
      await helpfulRef.delete();
    } else {
      await helpfulRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> reportReview({
    required String category,
    required String venueId,
    required String reviewUserId,
    String reason = 'uygunsuz_icerik',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Şikâyet etmek için giriş yapmalısın.');
    if (reviewUserId == user.uid) {
      throw Exception('Kendi yorumunu şikâyet edemezsin.');
    }
    final reviewRef = _ratings(category, venueId).doc(reviewUserId);
    final review = await reviewRef.get();
    if (!review.exists) throw Exception('Yorum artık mevcut değil.');
    final cleanReason = reason.trim();
    if (cleanReason.length < 3 || cleanReason.length > 120) {
      throw Exception('Geçerli bir şikâyet nedeni seç.');
    }
    final reportId =
        '${venueKey(category, venueId)}_${reviewUserId}_${user.uid}';
    await _firestore.collection('review_reports').doc(reportId).set({
      'venueKey': venueKey(category, venueId),
      'category': category,
      'venueId': venueId,
      'reviewUserId': reviewUserId,
      'reporterId': user.uid,
      'reason': cleanReason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }
}
