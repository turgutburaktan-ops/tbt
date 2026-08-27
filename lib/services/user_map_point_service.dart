import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_map_point.dart';

class UserMapPointService {
  UserMapPointService._();
  static final instance = UserMapPointService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, Future<void>> _deleteInFlight = {};
  Future<String>? _addInFlight;

  CollectionReference<Map<String, dynamic>> _points(String uid) =>
      _firestore.collection('users').doc(uid).collection('map_points');

  Stream<List<UserMapPoint>> watchMine() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(const <UserMapPoint>[]);
      return _points(user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(UserMapPoint.fromDoc)
                .toList(growable: false),
          );
    });
  }

  Future<String> addPoint({
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    required bool communitySuggested,
  }) {
    final running = _addInFlight;
    if (running != null) return running;

    final request = _addPointInternal(
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      communitySuggested: communitySuggested,
    );
    _addInFlight = request;
    return request.whenComplete(() {
      if (identical(_addInFlight, request)) _addInFlight = null;
    });
  }

  Future<String> _addPointInternal({
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
    await doc.set(data).timeout(const Duration(seconds: 8));

    // The private point is the primary user action. A moderation/suggestion
    // mirror must never make a successfully saved personal point look failed.
    if (communitySuggested) {
      unawaited(_mirrorSuggestionQuietly(doc.id, user.uid, data));
    }
    return doc.id;
  }

  Future<void> _mirrorSuggestionQuietly(
    String pointId,
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('map_point_suggestions').doc(pointId).set({
        ...data,
        'sourcePath': 'users/$userId/map_points/$pointId',
      }).timeout(const Duration(seconds: 7));
    } catch (_) {}
  }

  Future<void> deleteMine(String id) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || id.trim().isEmpty) return Future.value();
    final key = '$uid:$id';
    final running = _deleteInFlight[key];
    if (running != null) return running;

    final request = _points(uid)
        .doc(id)
        .delete()
        .timeout(const Duration(seconds: 7));
    _deleteInFlight[key] = request;
    return request.whenComplete(() {
      if (identical(_deleteInFlight[key], request)) _deleteInFlight.remove(key);
    });
  }
}
