import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/social_event.dart';
import 'social_event_service.dart';

class EventAttendanceService {
  EventAttendanceService._();
  static final EventAttendanceService instance = EventAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> setChoice(String eventId, EventAttendanceChoice choice) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Etkinliğe katılmak için giriş yapmalısın.');

    final ref = _firestore.collection(SocialEventService.collection).doc(eventId);

    if (choice == EventAttendanceChoice.interested) {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(ref);
        if (!snap.exists) throw Exception('Etkinlik artık mevcut değil.');
        final data = snap.data() ?? const <String, dynamic>{};
        final participants = _ids(data['participantIds'])..remove(user.uid);
        final hidden = _ids(data['hiddenParticipantIds'])..remove(user.uid);
        final interested = _ids(data['interestedIds']);
        if (!interested.contains(user.uid)) interested.add(user.uid);
        transaction.update(ref, {
          'participantIds': participants,
          'hiddenParticipantIds': hidden,
          'interestedIds': interested,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return;
    }

    // Reuse the existing ticket, capacity, trust and notification flow.
    await SocialEventService.instance.join(eventId);

    if (choice == EventAttendanceChoice.hidden) {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? const <String, dynamic>{};
        final participants = _ids(data['participantIds'])..remove(user.uid);
        final hidden = _ids(data['hiddenParticipantIds']);
        final interested = _ids(data['interestedIds'])..remove(user.uid);
        if (!hidden.contains(user.uid)) hidden.add(user.uid);
        transaction.update(ref, {
          'participantIds': participants,
          'hiddenParticipantIds': hidden,
          'interestedIds': interested,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      await ref.update({
        'hiddenParticipantIds': FieldValue.arrayRemove([user.uid]),
        'interestedIds': FieldValue.arrayRemove([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> clearChoice(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _firestore.collection(SocialEventService.collection).doc(eventId);
    await ref.update({
      'hiddenParticipantIds': FieldValue.arrayRemove([user.uid]),
      'interestedIds': FieldValue.arrayRemove([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await SocialEventService.instance.leave(eventId);
  }

  List<String> _ids(dynamic value) => value is List
      ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : <String>[];
}
