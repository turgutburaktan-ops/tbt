import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrustSafetyService {
  TrustSafetyService._();
  static final instance = TrustSafetyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Giriş gerekli.');
    return uid;
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    final cleanReason = reason.trim();
    final cleanDetails = details.trim();
    final limitedDetails = cleanDetails.length > 1000
        ? cleanDetails.substring(0, 1000)
        : cleanDetails;
    if (cleanReason.length < 3) throw ArgumentError('Geçerli bir şikâyet nedeni gerekli.');
    await _db.collection('moderation_reports').add({
      'reporterId': _uid,
      'targetType': targetType.trim(),
      'targetId': targetId.trim(),
      'reason': cleanReason,
      'details': limitedDetails,
      'status': 'open',
      'priority': 'normal',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(String targetUid) async {
    if (targetUid.isEmpty || targetUid == _uid) return;
    await _db.collection('users').doc(_uid).collection('blocked').doc(targetUid).set({
      'userId': targetUid,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String targetUid) async {
    await _db.collection('users').doc(_uid).collection('blocked').doc(targetUid).delete();
  }

  Future<void> updateNotificationPreferences(Map<String, bool> prefs) async {
    await _db.collection('users').doc(_uid).set({
      'notificationPreferences': prefs,
      'notificationPreferencesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updatePrivacy({
    required String locationVisibility,
    required bool preciseEventLocationOnlyForAttendees,
    required bool analyticsConsent,
  }) async {
    await _db.collection('users').doc(_uid).set({
      'privacy': {
        'locationVisibility': locationVisibility,
        'preciseEventLocationOnlyForAttendees': preciseEventLocationOnlyForAttendees,
        'analyticsConsent': analyticsConsent,
      },
      'privacyUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> requestAccountDeletion({String reason = ''}) async {
    await _db.collection('account_delete_requests').doc(_uid).set({
      'uid': _uid,
      'reason': reason.trim(),
      'status': 'requested',
      'requestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class EventSafetyService {
  EventSafetyService._();
  static final instance = EventSafetyService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> applySafetyDefaults(String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('social_events').doc(eventId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['hostId'] != uid) return;
    await ref.set({
      'safety': {
        'preciseLocationAttendeesOnly': true,
        'waitlistEnabled': true,
        'hostCanRemoveParticipants': true,
        'organizerHistoryVisible': true,
        'reportingEnabled': true,
      },
      'safetyUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> requestWaitlist(String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Giriş gerekli.');
    await _db.collection('social_events').doc(eventId).collection('waitlist').doc(uid).set({
      'userId': uid,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordNoShow(String eventId, String participantUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final event = await _db.collection('social_events').doc(eventId).get();
    if (event.data()?['hostId'] != uid) throw StateError('Yalnız organizatör işlem yapabilir.');
    await _db.collection('users').doc(participantUid).collection('event_reliability').doc(eventId).set({
      'eventId': eventId,
      'status': 'no_show',
      'recordedBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class BusinessTrustService {
  BusinessTrustService._();
  static final instance = BusinessTrustService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> flagVenue({required String venueKey, required String reason}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Giriş gerekli.');
    await _db.collection('business_venues').doc(venueKey).collection('trust_reports').add({
      'reporterId': uid,
      'reason': reason.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
