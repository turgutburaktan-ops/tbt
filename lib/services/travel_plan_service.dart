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
    DateTime? startAt,
    double distanceKm = 0,
    int travelMinutes = 0,
    int estimatedBudget = 0,
    String weatherSummary = '',
    bool isPublic = false,
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
      'stopSnapshots': spots
          .map(
            (spot) => {
              'id': spot.id,
              'name': spot.name,
              'city': spot.city,
              'latitude': spot.latitude,
              'longitude': spot.longitude,
              'category': spot.category,
              'bestTime': spot.bestTime,
            },
          )
          .toList(growable: false),
      'memberIds': [user.uid],
      'startAt': Timestamp.fromDate(startAt ?? DateTime.now()),
      'distanceKm': distanceKm,
      'travelMinutes': travelMinutes,
      'estimatedBudget': estimatedBudget,
      'weatherSummary': weatherSummary,
      'isPublic': isPublic,
      'ratingTotal': 0,
      'ratingCount': 0,
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

  Future<void> setPublic(String planId, bool value) async {
    _requireUser();
    await _firestore.collection('travel_plans').doc(planId).update({
      'isPublic': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> publishToFeed(TravelPlan plan) async {
    final user = _requireUser();
    if (plan.ownerId != user.uid) {
      throw Exception('Yalnızca kendi rotanı paylaşabilirsin.');
    }
    final postRef = _firestore.collection('posts').doc('route_${plan.id}');
    final existing = await postRef.get();
    await _firestore.collection('travel_plans').doc(plan.id).update({
      'isPublic': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await postRef.set({
      'userId': user.uid,
      'userName': (user.displayName ?? '').trim().isEmpty
          ? 'TBT kullanıcısı'
          : user.displayName!.trim(),
      'userPhotoUrl': user.photoURL ?? '',
      'mediaType': 'route',
      'contentType': 'route',
      'travelPlanId': plan.id,
      'routeTitle': plan.title,
      'routeCity': plan.city,
      'routeDurationHours': plan.durationHours,
      'routeBudget': plan.budget,
      'routeTransport': plan.transport,
      'routeSpotIds': plan.spotIds,
      'routeSpotNames': plan.spotNames,
      'routeStopSnapshots': plan.stopSnapshots,
      'caption': '${plan.title} rotasını paylaştı.',
      'spotName': plan.city,
      'isPublic': true,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return postRef.id;
  }

  Future<void> addStop(String planId, PhotoSpot spot) async {
    _requireUser();
    await _firestore.collection('travel_plans').doc(planId).update({
      'spotIds': FieldValue.arrayUnion([spot.id]),
      'spotNames': FieldValue.arrayUnion([spot.name]),
      'stopSnapshots': FieldValue.arrayUnion([
        {
          'id': spot.id,
          'name': spot.name,
          'city': spot.city,
          'latitude': spot.latitude,
          'longitude': spot.longitude,
          'category': spot.category,
          'bestTime': spot.bestTime,
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addCustomStop({
    required String planId,
    required String name,
    required double latitude,
    required double longitude,
    String city = '',
  }) async {
    _requireUser();
    final cleanName = name.trim().isEmpty ? 'Haritadan seçilen durak' : name.trim();
    final id =
        'custom_${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}';
    await _firestore.collection('travel_plans').doc(planId).update({
      'spotIds': FieldValue.arrayUnion([id]),
      'spotNames': FieldValue.arrayUnion([cleanName]),
      'stopSnapshots': FieldValue.arrayUnion([
        {
          'id': id,
          'name': cleanName,
          'city': city,
          'latitude': latitude,
          'longitude': longitude,
          'category': 'Özel durak',
          'bestTime': '',
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<TravelPlan>> watchPublic() {
    return _firestore
        .collection('travel_plans')
        .where('isPublic', isEqualTo: true)
        .limit(80)
        .snapshots()
        .map((snapshot) {
          final plans = snapshot.docs.map(TravelPlan.fromDoc).toList();
          plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return plans;
        });
  }

  Future<void> rate(String planId, int rating) async {
    final user = _requireUser();
    if (rating < 1 || rating > 5) return;
    await _firestore
        .collection('travel_plans')
        .doc(planId)
        .collection('ratings')
        .doc(user.uid)
        .set({
          'userId': user.uid,
          'rating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<List<PhotoSpot>> resolveSpots(TravelPlan plan) async {
    final all = await SpotRepository.instance.loadSpots();
    final byId = {for (final spot in all) spot.id: spot};
    final snapshots = {
      for (final item in plan.stopSnapshots) (item['id'] ?? '').toString(): item,
    };
    return plan.spotIds.map((id) {
      final existing = byId[id];
      if (existing != null) return existing;
      final item = snapshots[id];
      if (item == null) return null;
      return PhotoSpot(
        id: id,
        name: (item['name'] ?? 'Rota durağı').toString(),
        city: (item['city'] ?? plan.city).toString(),
        latitude: (item['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (item['longitude'] as num?)?.toDouble() ?? 0,
        rating: 0,
        bestTime: (item['bestTime'] ?? '').toString(),
        angle: '',
        imageUrl: '',
        category: (item['category'] ?? 'Mekan').toString(),
      );
    }).whereType<PhotoSpot>().toList(growable: false);
  }
}
