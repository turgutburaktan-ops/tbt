import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_ticket.dart';
import '../models/social_event.dart';
import 'app_notification_service.dart';
import 'chat_service.dart';
import 'event_ticket_service.dart';
import 'social_event_service.dart';

class EventAttendanceService {
  EventAttendanceService._();
  static final EventAttendanceService instance = EventAttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};

  Stream<String?> watchMine(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection(SocialEventService.collection)
        .doc(eventId)
        .collection('attendance')
        .doc(user.uid)
        .snapshots()
        .map(
          (doc) => doc.exists ? (doc.data()?['status'] ?? '').toString() : null,
        );
  }

  Future<void> setChoice(String eventId, EventAttendanceChoice choice) async {
    final status = switch (choice) {
      EventAttendanceChoice.attending => 'going',
      EventAttendanceChoice.interested => 'interested',
      EventAttendanceChoice.hidden => 'private',
    };
    await setStatus(eventId, status);
  }

  Future<void> clearChoice(String eventId) => setStatus(eventId, 'none');

  Future<void> setStatus(String eventId, String status) {
    final key = '${_auth.currentUser?.uid ?? 'guest'}:$eventId';
    final running = _inFlight[key];
    if (running != null) return running;

    final request = _setStatusInternal(eventId, status);
    _inFlight[key] = request;
    return request.whenComplete(() {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    });
  }

  Future<void> _setStatusInternal(String eventId, String status) async {
    const valid = {'going', 'interested', 'private', 'none'};
    if (!valid.contains(status)) throw Exception('Geçersiz katılım seçimi.');

    final user = _auth.currentUser;
    if (user == null) throw Exception('Etkinlik işlemi için giriş yapmalısın.');

    final eventRef = _firestore
        .collection(SocialEventService.collection)
        .doc(eventId);
    final attendanceRef = eventRef.collection('attendance').doc(user.uid);
    final ticketRef = _firestore
        .collection(EventTicketService.collection)
        .doc(EventTicketService.instance.ticketIdFor(eventId, user.uid));
    final qrToken = EventTicketService.instance.createSecureQrToken();

    final result = await _firestore.runTransaction<Map<String, String>>((
      tx,
    ) async {
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) throw Exception('Etkinlik artık mevcut değil.');
      final data = eventSnap.data() ?? const <String, dynamic>{};
      final hostId = (data['hostId'] ?? '').toString();
      if (hostId == user.uid) {
        throw Exception('Etkinlik sahibi katılım durumunu değiştiremez.');
      }
      if ((data['status'] ?? 'open') != 'open') {
        throw Exception('Bu etkinlik katılıma kapalı.');
      }

      final visibility = (data['visibility'] ?? EventVisibility.public.name)
          .toString();
      final allowed = (data['allowedUserIds'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (visibility != EventVisibility.public.name &&
          !allowed.contains(user.uid)) {
        throw Exception('Bu etkinlik sadece davet edilen kullanıcılar için.');
      }

      final accessType = (data['accessType'] ?? EventAccessType.free.name)
          .toString();
      final paymentStatus =
          (data['paymentStatus'] ?? EventPaymentStatus.notRequired.name)
              .toString();
      final trustStatus = (data['trustStatus'] ?? 'new_host').toString();
      final salesStatus = (data['salesStatus'] ?? 'blocked').toString();
      if ((status == 'going' || status == 'private') &&
          accessType == EventAccessType.paid.name &&
          (paymentStatus != EventPaymentStatus.enabled.name ||
              trustStatus != 'approved' ||
              salesStatus != 'open')) {
        throw Exception(
          'Bu ücretli etkinlik güvenlik onayı tamamlanmadan bilet satışına açılamaz.',
        );
      }

      final attendanceSnap = await tx.get(attendanceRef);
      final previous = attendanceSnap.exists
          ? (attendanceSnap.data()?['status'] ?? '').toString()
          : '';

      final participants = (data['participantIds'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      var interestedCount = ((data['interestedCount'] as num?)?.toInt() ?? 0)
          .clamp(0, 2147483647);
      var privateCount =
          ((data['privateParticipantCount'] as num?)?.toInt() ?? 0).clamp(
            0,
            2147483647,
          );

      participants.remove(user.uid);
      if (previous == 'interested' && interestedCount > 0) interestedCount--;
      if (previous == 'private' && privateCount > 0) privateCount--;

      final capacity = ((data['capacity'] as num?)?.toInt() ?? 1).clamp(
        1,
        2147483647,
      );
      if ((status == 'going' || status == 'private') &&
          participants.length + privateCount >= capacity) {
        throw Exception('Bu etkinlikte boş yer kalmadı.');
      }

      if (status == 'going') participants.add(user.uid);
      if (status == 'private') privateCount++;
      if (status == 'interested') interestedCount++;

      tx.update(eventRef, {
        'participantIds': participants,
        'interestedCount': interestedCount,
        'privateParticipantCount': privateCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'none') {
        if (attendanceSnap.exists) tx.delete(attendanceRef);
      } else {
        tx.set(attendanceRef, {
          'userId': user.uid,
          'userName': (user.displayName ?? '').trim().isEmpty
              ? 'Katılımcı'
              : user.displayName!.trim(),
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (status == 'going' || status == 'private') {
        final paid = accessType == EventAccessType.paid.name;
        tx.set(ticketRef, {
          'id': ticketRef.id,
          'eventId': eventId,
          'eventTitle': (data['title'] ?? 'Etkinlik').toString(),
          'userId': user.uid,
          'userName': (user.displayName ?? '').trim().isEmpty
              ? 'Katılımcı'
              : user.displayName!.trim(),
          'status': paid
              ? EventTicketStatus.pendingPayment.name
              : EventTicketStatus.active.name,
          'isPaidEvent': paid,
          'priceMinor': ((data['ticketPriceMinor'] as num?)?.toInt() ?? 0),
          'currency': (data['currency'] ?? 'TRY').toString(),
          'qrToken': qrToken,
          'issuedAt': FieldValue.serverTimestamp(),
          'usedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return {
        'hostId': hostId,
        'title': (data['title'] ?? 'Etkinlik').toString(),
      };
    });

    if (status != 'going' && status != 'private') {
      try {
        await ticketRef.update({
          'status': EventTicketStatus.cancelled.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    final hostId = result['hostId'] ?? '';
    if (hostId.isNotEmpty && (status == 'going' || status == 'private')) {
      unawaited(
        _runJoinSideEffects(
          hostId: hostId,
          eventId: eventId,
          title: result['title'] ?? 'Etkinlik',
          status: status,
          userId: user.uid,
          displayName: user.displayName,
        ),
      );
    }
  }

  Future<void> _runJoinSideEffects({
    required String hostId,
    required String eventId,
    required String title,
    required String status,
    required String userId,
    required String? displayName,
  }) async {
    try {
      await ChatService.instance
          .ensureDirectThread(
            hostId,
            sourceType: 'social_event',
            sourceId: eventId,
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      await AppNotificationService.instance
          .notifyUser(
            userId: hostId,
            type: 'event_join',
            title: status == 'private'
                ? 'Bir kullanıcı etkinliğine gizli katıldı'
                : '${displayName ?? 'Bir kullanıcı'} etkinliğine katıldı',
            body: title,
            sourceId: eventId,
            actorId: status == 'private' ? null : userId,
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
