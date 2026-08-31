import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/travel_plan.dart';

class TravelPlanCollaborationService {
  TravelPlanCollaborationService._();

  static final instance = TravelPlanCollaborationService._();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _uid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Giriş yapmalısın.');
    return uid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String planId) =>
      _firestore
          .collection('travel_plans')
          .doc(planId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(120)
          .snapshots();

  Future<void> sendMessage(String planId, String text) async {
    final uid = _uid();
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 1000) return;
    final user = _auth.currentUser!;
    await _firestore
        .collection('travel_plans')
        .doc(planId)
        .collection('messages')
        .add({
          'senderId': uid,
          'senderName': (user.displayName ?? '').trim().isEmpty
              ? 'TBT kullanıcısı'
              : user.displayName!.trim(),
          'text': clean,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> proposals(String planId) =>
      _firestore
          .collection('travel_plans')
          .doc(planId)
          .collection('proposals')
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<void> propose(
    String planId,
    String text, {
    String spotId = '',
    double? latitude,
    double? longitude,
    String city = '',
  }) async {
    final uid = _uid();
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 180) return;
    await _firestore
        .collection('travel_plans')
        .doc(planId)
        .collection('proposals')
        .add({
          'authorId': uid,
          'text': clean,
          if (spotId.isNotEmpty) 'spotId': spotId,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (city.isNotEmpty) 'city': city,
          'voterIds': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> setMeetingPoint({
    required String planId,
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    final uid = _uid();
    await _firestore.collection('travel_plans').doc(planId).update({
      'meetingPoint': {
        'label': label.trim().isEmpty ? 'Buluşma noktası' : label.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'selectedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> vote(String planId, String proposalId) async {
    final uid = _uid();
    await _firestore
        .collection('travel_plans')
        .doc(planId)
        .collection('proposals')
        .doc(proposalId)
        .update({
          'voterIds': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> acceptProposal(String planId, String proposalId) async {
    _uid();
    await _firestore
        .collection('travel_plans')
        .doc(planId)
        .collection('proposals')
        .doc(proposalId)
        .update({
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> liveStates(String planId) =>
      _firestore
          .collection('travel_plans')
          .doc(planId)
          .collection('live_states')
          .snapshots();

  Future<void> setLiveState({
    required String planId,
    required int stopIndex,
    required String stopName,
    required bool active,
    double? latitude,
    double? longitude,
  }) async {
    final uid = _uid();
    final user = _auth.currentUser!;
    await _firestore
        .collection('travel_plans')
        .doc(planId)
        .collection('live_states')
        .doc(uid)
        .set({
          'userId': uid,
          'userName': (user.displayName ?? '').trim().isEmpty
              ? 'TBT kullanıcısı'
              : user.displayName!.trim(),
          'stopIndex': stopIndex,
          'stopName': stopName,
          'active': active,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> saveOffline(TravelPlan plan) async {
    final preferences = await SharedPreferences.getInstance();
    final data = {
      'id': plan.id,
      'title': plan.title,
      'city': plan.city,
      'startAt': plan.startAt.toIso8601String(),
      'distanceKm': plan.distanceKm,
      'travelMinutes': plan.travelMinutes,
      'estimatedBudget': plan.estimatedBudget,
      'weatherSummary': plan.weatherSummary,
      'spotNames': plan.spotNames,
      'stopSnapshots': plan.stopSnapshots,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await preferences.setString('offline_travel_plan_${plan.id}', jsonEncode(data));
    final ids = preferences.getStringList('offline_travel_plan_ids') ?? [];
    if (!ids.contains(plan.id)) {
      await preferences.setStringList('offline_travel_plan_ids', [...ids, plan.id]);
    }
  }

  Future<bool> isOffline(String planId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.containsKey('offline_travel_plan_$planId');
  }
}
