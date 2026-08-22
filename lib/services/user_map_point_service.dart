import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_map_point.dart';

class UserMapPointService {
  UserMapPointService._();
  static final instance = UserMapPointService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _points(String uid) =>
      _firestore.collection('users').doc(uid).collection('map_points');

  Stream<List<UserMapPoint>> watchMine() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream<List<UserMapPoint>>.empty();
    return _points(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UserMapPoint.fromDoc).toList());
  }

  Future<String> addPoint({
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    required bool communitySuggested,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Nokta eklemek için giriş yapmalısın.');
    final cleanName = name.trim();
    if (cleanName.length < 2) throw Exception('Nokta adı çok kısa.');

    final doc = _points(user.uid).doc();
    final data = <String, dynamic>{
      'ownerId': user.uid,
      'ownerName': user.displayName ?? '',
      'name': cleanName,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'communitySuggested': communitySuggested,
      'moderationStatus': communitySuggested ? 'pending' : 'private',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await doc.set(data);

    if (communitySuggested) {
      await _firestore.collection('map_point_suggestions').doc(doc.id).set({
        ...data,
        'sourcePath': 'users/${user.uid}/map_points/${doc.id}',
      });
    }
    return doc.id;
  }

  Future<void> deleteMine(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _points(uid).doc(id).delete();
  }
}
