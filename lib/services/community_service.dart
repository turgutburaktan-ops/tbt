import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityService {
  CommunityService._();
  static final CommunityService instance = CommunityService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCommunities({String? university}) {
    Query<Map<String, dynamic>> query = _firestore.collection('communities');
    if (university != null && university.trim().isNotEmpty) {
      query = query.where('university', isEqualTo: university.trim());
    }
    return query.snapshots();
  }

  Stream<bool> isFollowing(String communityId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _firestore.collection('communities').doc(communityId).collection('followers').doc(uid).snapshots().map((d) => d.exists);
  }

  Stream<int> followerCount(String communityId) => _firestore
      .collection('communities')
      .doc(communityId)
      .collection('followers')
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> toggleFollow(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Topluluğu takip etmek için giriş yapmalısın.');
    final ref = _firestore.collection('communities').doc(communityId).collection('followers').doc(user.uid);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.delete();
    } else {
      await ref.set({'userId': user.uid, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  Future<String> createCommunity({required String name, required String university, String description = ''}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Topluluk oluşturmak için giriş yapmalısın.');
    final cleanName = name.trim();
    if (cleanName.length < 3) throw Exception('Topluluk adı en az 3 karakter olmalı.');
    final ref = _firestore.collection('communities').doc();
    await ref.set({
      'id': ref.id,
      'name': cleanName,
      'university': university.trim(),
      'description': description.trim(),
      'ownerId': user.uid,
      'adminIds': [user.uid],
      'verificationStatus': 'pending',
      'verified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await ref.collection('followers').doc(user.uid).set({'userId': user.uid, 'createdAt': FieldValue.serverTimestamp()});
    return ref.id;
  }
}
