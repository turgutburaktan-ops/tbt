import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_notification_service.dart';

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

    final userRef = _firestore.collection('users').doc(user.uid);

    final snapshot = await userRef.get();

    final data = {
      'uid': user.uid,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : 'Fotoğrafçı',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      await userRef.set({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await userRef.set(data, SetOptions(merge: true));
    }
  }

  // =========================================================
  // KULLANICI PROFİLİ
  // =========================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
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
        .map((snapshot) => snapshot.exists);
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

    final existing = await followingRef.get();

    if (existing.exists) {
      return;
    }

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

    await batch.commit();

    try {
      final displayName = (user.displayName ?? '').trim().isEmpty
          ? 'Bir kullanıcı'
          : user.displayName!.trim();
      await AppNotificationService.instance.notifyUser(
        userId: targetUserId,
        type: 'follow',
        title: '$displayName seni takip etmeye başladı',
        body: 'Profilini görmek için dokun.',
        actorId: user.uid,
      );
    } catch (_) {
      // Takip işlemi başarılıysa bildirim hatası ana işlemi bozmaz.
    }
  }

  // =========================================================
  // TAKİBİ BIRAK
  // =========================================================

  Future<void> unfollowUser(String targetUserId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Giriş yapmalısın.');
    }

    if (user.uid == targetUserId) {
      return;
    }

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

    final batch = _firestore.batch();

    batch.delete(followingRef);

    batch.delete(followerRef);

    await batch.commit();
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
  // TAKİP EDİLEN KULLANICI ID'LERİ
  // Akış ekranında kullanacağız.
  // =========================================================

  Stream<List<String>> followingIds() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.value(<String>[]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // =========================================================
  // TAKİPÇİLER
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> followers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .snapshots();
  }

  // =========================================================
  // TAKİP EDİLENLER
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> following(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots();
  }

  // =========================================================
  // KULLANICININ PAYLAŞIMLARI
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> userPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }
}
