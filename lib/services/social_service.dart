import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_notification_service.dart';

class SocialService {
  SocialService._();

  static final SocialService instance = SocialService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, Future<void>> _followMutations = {};
  Future<void>? _ensureProfileInFlight;

  User? get currentUser => _auth.currentUser;

  Future<void> ensureUserProfile() {
    final running = _ensureProfileInFlight;
    if (running != null) return running;

    final request = _ensureUserProfileInternal();
    _ensureProfileInFlight = request;
    return request.whenComplete(() {
      if (identical(_ensureProfileInFlight, request)) {
        _ensureProfileInFlight = null;
      }
    });
  }

  Future<void> _ensureUserProfileInternal() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get().timeout(const Duration(seconds: 6));
    final existing = snapshot.data();

    if (!snapshot.exists || existing == null) {
      await userRef.set({
        'uid': user.uid,
        'displayName': user.displayName?.trim().isNotEmpty == true
            ? user.displayName
            : 'Fotoğrafçı',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 7));
      return;
    }

    // Merely opening a profile must not rewrite the user document. Rewriting
    // updatedAt on every visit used to fan out unnecessary snapshots across
    // profile, nearby and social screens.
    final patch = <String, dynamic>{};
    if ((existing['uid'] ?? '').toString().isEmpty) patch['uid'] = user.uid;
    if ((existing['displayName'] ?? '').toString().trim().isEmpty &&
        (user.displayName ?? '').trim().isNotEmpty) {
      patch['displayName'] = user.displayName!.trim();
    }
    if ((existing['email'] ?? '').toString().trim().isEmpty &&
        (user.email ?? '').trim().isNotEmpty) {
      patch['email'] = user.email!.trim();
    }
    if ((existing['photoUrl'] ?? '').toString().trim().isEmpty &&
        (user.photoURL ?? '').trim().isNotEmpty) {
      patch['photoUrl'] = user.photoURL!.trim();
    }
    if (patch.isEmpty) return;

    patch['updatedAt'] = FieldValue.serverTimestamp();
    await userRef
        .set(patch, SetOptions(merge: true))
        .timeout(const Duration(seconds: 7));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  Stream<bool> isFollowing(String targetUserId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((snapshot) => snapshot.exists)
        .distinct();
  }

  Future<void> followUser(String targetUserId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Future.error(Exception('Takip etmek için giriş yapmalısın.'));
    }
    if (user.uid == targetUserId) {
      return Future.error(Exception('Kendini takip edemezsin.'));
    }

    final key = '${user.uid}:$targetUserId';
    final running = _followMutations[key];
    if (running != null) return running;
    final request = _followUserInternal(user, targetUserId);
    _followMutations[key] = request;
    return request.whenComplete(() {
      if (identical(_followMutations[key], request)) _followMutations.remove(key);
    });
  }

  Future<void> _followUserInternal(User user, String targetUserId) async {
    await ensureUserProfile();

    final followingRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId);
    final followerRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(user.uid);

    final existing = await followingRef.get().timeout(const Duration(seconds: 6));
    if (existing.exists) return;

    final batch = _firestore.batch();
    batch.set(followingRef, {
      'userId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(followerRef, {
      'userId': user.uid,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : 'Fotoğrafçı',
      'photoUrl': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(const Duration(seconds: 8));

    final displayName = (user.displayName ?? '').trim().isEmpty
        ? 'Bir kullanıcı'
        : user.displayName!.trim();
    unawaited(_notifyQuietly(
      userId: targetUserId,
      type: 'follow',
      title: '$displayName seni takip etmeye başladı',
      body: 'Profilini görmek için dokun.',
      actorId: user.uid,
    ));
  }

  Future<void> unfollowUser(String targetUserId) {
    final user = _auth.currentUser;
    if (user == null) return Future.error(Exception('Giriş yapmalısın.'));
    if (user.uid == targetUserId) return Future.value();

    final key = '${user.uid}:$targetUserId';
    final running = _followMutations[key];
    if (running != null) return running;
    final request = _unfollowUserInternal(user.uid, targetUserId);
    _followMutations[key] = request;
    return request.whenComplete(() {
      if (identical(_followMutations[key], request)) _followMutations.remove(key);
    });
  }

  Future<void> _unfollowUserInternal(String uid, String targetUserId) async {
    final followingRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUserId);
    final followerRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(uid);

    final batch = _firestore.batch();
    batch.delete(followingRef);
    batch.delete(followerRef);
    await batch.commit().timeout(const Duration(seconds: 8));
  }

  Future<void> toggleFollow(String targetUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Giriş yapmalısın.');
    if (user.uid == targetUserId) return;

    final key = '${user.uid}:$targetUserId';
    final running = _followMutations[key];
    if (running != null) return running;

    final request = _toggleFollowInternal(user, targetUserId);
    _followMutations[key] = request;
    try {
      await request;
    } finally {
      if (identical(_followMutations[key], request)) _followMutations.remove(key);
    }
  }

  Future<void> _toggleFollowInternal(User user, String targetUserId) async {
    final followingRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId);
    final snapshot = await followingRef.get().timeout(const Duration(seconds: 6));
    if (snapshot.exists) {
      await _unfollowUserInternal(user.uid, targetUserId);
    } else {
      await _followUserInternal(user, targetUserId);
    }
  }

  Stream<int> followersCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .distinct();
  }

  Stream<int> followingCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .distinct();
  }

  Stream<List<String>> followingIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(<String>[]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> followers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> following(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> _notifyQuietly({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String actorId,
  }) async {
    try {
      await AppNotificationService.instance
          .notifyUser(
            userId: userId,
            type: type,
            title: title,
            body: body,
            actorId: actorId,
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }
}
