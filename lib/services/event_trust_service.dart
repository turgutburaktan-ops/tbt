import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventTrustEligibility {
  final bool allowed;
  final String reason;
  final int accountAgeHours;

  const EventTrustEligibility({
    required this.allowed,
    required this.reason,
    required this.accountAgeHours,
  });
}

class EventTrustService {
  EventTrustService._();

  static final EventTrustService instance = EventTrustService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<EventTrustEligibility> paidEventEligibility() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const EventTrustEligibility(
        allowed: false,
        reason: 'Ücretli etkinlik oluşturmak için giriş yapmalısın.',
        accountAgeHours: 0,
      );
    }

    final createdAt = user.metadata.creationTime;
    final age = createdAt == null
        ? Duration.zero
        : DateTime.now().difference(createdAt.toLocal());
    final ageHours = age.inHours;

    if (!user.emailVerified) {
      return EventTrustEligibility(
        allowed: false,
        reason: 'Ücretli etkinlik için önce e-posta adresini doğrulamalısın.',
        accountAgeHours: ageHours,
      );
    }

    if (age < const Duration(hours: 24)) {
      return EventTrustEligibility(
        allowed: false,
        reason:
            'Yeni hesaplarda ücretli etkinlik 24 saat sonra açılır. Bu sürede ücretsiz etkinlik oluşturabilirsin.',
        accountAgeHours: ageHours,
      );
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    final displayName = (data['displayName'] ?? user.displayName ?? '').toString().trim();
    final photoUrl = (data['photoUrl'] ?? user.photoURL ?? '').toString().trim();

    if (displayName.length < 3 || photoUrl.isEmpty) {
      return EventTrustEligibility(
        allowed: false,
        reason:
            'Ücretli etkinlik için profil adını ve profil fotoğrafını tamamlamalısın.',
        accountAgeHours: ageHours,
      );
    }

    return EventTrustEligibility(
      allowed: true,
      reason: 'Ücretli etkinlik oluşturabilirsin.',
      accountAgeHours: ageHours,
    );
  }

  Future<void> reportEvent({
    required String eventId,
    required String reason,
    String details = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Etkinliği bildirmek için giriş yapmalısın.');

    final eventRef = _firestore.collection('social_events').doc(eventId);
    final reportRef = eventRef.collection('reports').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      if (!eventSnapshot.exists) throw Exception('Etkinlik artık mevcut değil.');

      final event = eventSnapshot.data() ?? const <String, dynamic>{};
      if ((event['hostId'] ?? '').toString() == user.uid) {
        throw Exception('Kendi etkinliğini bildiremezsin.');
      }

      final oldReport = await transaction.get(reportRef);
      if (oldReport.exists) throw Exception('Bu etkinliği daha önce bildirdin.');

      final currentCount = (event['reportCount'] as num?)?.toInt() ?? 0;
      final nextCount = currentCount + 1;

      transaction.set(reportRef, {
        'reporterId': user.uid,
        'reason': reason.trim(),
        'details': details.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final update = <String, dynamic>{
        'reportCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nextCount >= 3) {
        update['trustStatus'] = 'under_review';
        update['salesStatus'] = 'blocked';
        update['riskLevel'] = 'high';
      }
      transaction.update(eventRef, update);
    });
  }

  String trustLabel(String trustStatus) {
    switch (trustStatus) {
      case 'verified':
        return 'Doğrulanmış organizatör';
      case 'approved':
        return 'Onaylı etkinlik';
      case 'under_review':
        return 'İncelemede';
      case 'pending_review':
        return 'Onay bekliyor';
      default:
        return 'Yeni organizatör';
    }
  }
}
