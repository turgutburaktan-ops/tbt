import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialService {
  SocialService._();

  static final SocialService instance = SocialService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // =========================================================
  // KULLANICI PROFİLİNİ FIRESTORE'A HAZIRLA
  // =========================================================

  Future<void> ensureUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) return;

    final ref = _firestore.collection('users').doc(user.uid);

    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'displayName':
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName
                : 'Fotoğrafçı',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'followersCount': 0,
        'followingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'uid': user.uid,
        'displayName':
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName
                : 'Fotoğrafçı',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
      }, SetOptions(merge: true));
    }
  }

  // =========================================================
  // TAKİP EDİYOR MU?
  // =========================================================

  Stream<bool> isFollowing(String targetUserId) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // =========================================================
  // TAKİP ET
  // =========================================================

  Future<void> followUser(String targetUserId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Takip etmek için giriş yapmalısın.');
    }

    if (user.uid == targetUserId) {
      throw Exception('Kendini takip edemezsin.');
    }

    await ensureUserProfile();

    final currentUserRef =
        _firestore.collection('users').doc(user.uid);

    final targetUserRef =
        _firestore.collection('users').doc(targetUserId);

    final followingRef =
        currentUserRef.collection('following').doc(targetUserId);

    final followerRef =
        targetUserRef.collection('followers').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final followingSnapshot =
          await transaction.get(followingRef);

      // Zaten takip ediyorsa tekrar artırma.
      if (followingSnapshot.exists) {
        return;
      }

      transaction.set(followingRef, {
        'userId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(followerRef, {
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        currentUserRef,
        {
          'followingCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        targetUserRef,
        {
          'followersCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    });
  }

  // =========================================================
  // TAKİBİ BIRAK
  // =========================================================

  Future<void> unfollowUser(String targetUserId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Giriş yapmalısın.');
    }

    if (user.uid == targetUserId) return;

    final currentUserRef =
        _firestore.collection('users').doc(user.uid);

    final targetUserRef =
        _firestore.collection('users').doc(targetUserId);

    final followingRef =
        currentUserRef.collection('following').doc(targetUserId);

    final followerRef =
        targetUserRef.collection('followers').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final followingSnapshot =
          await transaction.get(followingRef);

      if (!followingSnapshot.exists) {
        return;
      }

      transaction.delete(followingRef);
      transaction.delete(followerRef);

      transaction.set(
        currentUserRef,
        {
          'followingCount': FieldValue.increment(-1),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        targetUserRef,
        {
          'followersCount': FieldValue.increment(-1),
        },
        SetOptions(merge: true),
      );
    });
  }

  // =========================================================
  // TAKİP ET / TAKİBİ BIRAK
  // =========================================================

  Future<void> toggleFollow(String targetUserId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Giriş yapmalısın.');
    }

    final followingRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .doc(targetUserId);

    final snapshot = await followingRef.get();

    if (snapshot.exists) {
      await unfollowUser(targetUserId);
    } else {
      await followUser(targetUserId);
    }
  }

  // =========================================================
  // KULLANICI PROFİLİ
  // =========================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfile(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots();
  }

  // =========================================================
  // TAKİPÇİ SAYISI
  // =========================================================

  Stream<int> followersCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // =========================================================
  // TAKİP EDİLEN SAYISI
  // =========================================================

  Stream<int> followingCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // =========================================================
  // TAKİP EDİLEN KULLANICILARIN ID'LERİ
  // Akış ekranında bunu kullanacağız.
  // =========================================================

  Stream<List<String>> followingIds() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.id)
              .toList(),
        );
  }
}
