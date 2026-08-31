import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_spot.dart';
import '../models/travel_plan.dart';
import 'spot_repository.dart';

class TravelPlanService {
  TravelPlanService._();

  static final TravelPlanService instance = TravelPlanService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Plan kaydetmek için giriş yapmalısın.');
    return user;
  }

  Stream<List<TravelPlan>> watchMine() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const <TravelPlan>[]);
    return _firestore
        .collection('travel_plans')
        .where('memberIds', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
          final plans = snapshot.docs.map(TravelPlan.fromDoc).toList();
          plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return plans;
        });
  }

  Future<String> create({
    required String title,
    required String city,
    required int durationHours,
    required String budget,
    required String transport,
    required List<String> interests,
    required List<PhotoSpot> spots,
  }) async {
    final user = _requireUser();
    final reference = _firestore.collection('travel_plans').doc();
    await reference.set({
      'ownerId': user.uid,
      'ownerName': (user.displayName ?? '').trim().isEmpty
          ? 'TBT kullanıcısı'
          : user.displayName!.trim(),
      'title': title.trim().isEmpty ? '$city gezi planı' : title.trim(),
      'city': city,
      'durationHours': durationHours,
      'budget': budget,
      'transport': transport,
      'interests': interests,
      'spotIds': spots.map((spot) => spot.id).toList(growable: false),
      'spotNames': spots.map((spot) => spot.name).toList(growable: false),
      'memberIds': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> invite({
    required String planId,
    required String planTitle,
    required Iterable<String> userIds,
  }) async {
    final user = _requireUser();
    final ids = userIds.where((id) => id.isNotEmpty && id != user.uid).toSet();
    if (ids.isEmpty) return;
    final batch = _firestore.batch();
    final plan = _firestore.collection('travel_plans').doc(planId);
    batch.update(plan, {
      'memberIds': FieldValue.arrayUnion(ids.toList()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final id in ids) {
      final notification = _firestore
          .collection('users')
          .doc(id)
          .collection('notifications')
          .doc();
      batch.set(notification, {
        'type': 'travel_plan_invite',
        'title': 'Gezi planına davet edildin',
        'body': '$planTitle planını Planla bölümünde görebilirsin.',
        'actorId': user.uid,
        'planId': planId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> delete(String planId) async {
    _requireUser();
    await _firestore.collection('travel_plans').doc(planId).delete();
  }

  Future<List<PhotoSpot>> resolveSpots(TravelPlan plan) async {
    final all = await SpotRepository.instance.loadSpots();
    final byId = {for (final spot in all) spot.id: spot};
    return plan.spotIds
        .map((id) => byId[id])
        .whereType<PhotoSpot>()
        .toList(growable: false);
  }
}
