import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_ticket.dart';
import '../models/photo_spot.dart';
import '../models/social_event.dart';
import 'app_notification_service.dart';
import 'chat_service.dart';
import 'event_ticket_service.dart';

class SocialEventService {
  SocialEventService._();

  static final SocialEventService instance = SocialEventService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String collection = 'social_events';

  Stream<List<SocialEvent>> watchUpcoming(
      {String? city, SocialEventType? type, int limit = 80}) {
    return _firestore
        .collection(collection)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final threshold = DateTime.now().subtract(const Duration(minutes: 30));
      final items = snapshot.docs.map(SocialEvent.fromDocument).where((event) {
        if (event.status != 'open' || !event.startsAt.isAfter(threshold))
          return false;
        if (city != null &&
            city.trim().isNotEmpty &&
            event.city.toLowerCase() != city.trim().toLowerCase()) return false;
        if (type != null && event.type != type) return false;
        return true;
      }).toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    });
  }

  Stream<List<SocialEvent>> watchForSpot(String spotId, {int limit = 40}) {
    return _firestore
        .collection(collection)
        .where('spotId', isEqualTo: spotId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final threshold = DateTime.now().subtract(const Duration(minutes: 30));
      final items = snapshot.docs
          .map(SocialEvent.fromDocument)
          .where((event) =>
              event.status == 'open' && event.startsAt.isAfter(threshold))
          .toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    });
  }

  Future<String> create({
    required String title,
    required SocialEventType type,
    required DateTime startsAt,
    required int capacity,
    required String city,
    String description = '',
    String locationLabel = '',
    String customTypeLabel = '',
    PhotoSpot? spot,
    EventAccessType accessType = EventAccessType.free,
    int ticketPriceMinor = 0,
    String currency = 'TRY',
    DateTime? ticketSalesEndAt,
    double? latitude,
    double? longitude,
  }) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception('Etkinlik oluşturmak için giriş yapmalısın.');

    final safeTitle = title.trim();
    if (safeTitle.length < 3)
      throw Exception('Etkinlik başlığı en az 3 karakter olmalı.');
    final minimum = DateTime.now().add(const Duration(minutes: 15));
    if (startsAt.isBefore(minimum))
      throw Exception('Etkinlik saati en az 15 dakika ileride olmalı.');
    if (type == SocialEventType.other && customTypeLabel.trim().length < 3)
      throw Exception('Diğer etkinlik türü için kısa bir ad yazmalısın.');
    if (accessType == EventAccessType.paid && ticketPriceMinor <= 0)
      throw Exception(
          'Ücretli etkinlik için geçerli bir bilet fiyatı yazmalısın.');

    final ref = _firestore.collection(collection).doc();
    final hostName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : 'Topluluk üyesi';

    await ref.set({
      'id': ref.id,
      'title': safeTitle,
      'type': type.name,
      'customTypeLabel': customTypeLabel.trim(),
      'hostId': user.uid,
      'hostName': hostName,
      'startsAt': Timestamp.fromDate(startsAt),
      'capacity': capacity < 1 ? 1 : capacity,
      'participantIds': [user.uid],
      'description': description.trim(),
      'city': city.trim().isNotEmpty ? city.trim() : (spot?.city ?? ''),
      'locationLabel': locationLabel.trim().isNotEmpty
          ? locationLabel.trim()
          : (spot?.name ?? ''),
      'spotId': spot?.id,
      'spotName': spot?.name,
      'latitude': latitude ?? spot?.latitude,
      'longitude': longitude ?? spot?.longitude,
      'location': latitude != null && longitude != null
          ? GeoPoint(latitude, longitude)
          : (spot == null ? null : GeoPoint(spot.latitude, spot.longitude)),
      'status': 'open',
      'approximateLocationOnly': false,
      'accessType': accessType.name,
      'ticketPriceMinor':
          accessType == EventAccessType.paid ? ticketPriceMinor : 0,
      'currency': currency,
      'ticketSalesEndAt': ticketSalesEndAt == null
          ? null
          : Timestamp.fromDate(ticketSalesEndAt),
      'paymentStatus': accessType == EventAccessType.paid
          ? EventPaymentStatus.comingSoon.name
          : EventPaymentStatus.notRequired.name,
      'paymentProvider': null,
      'externalProductId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> join(String eventId) async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception('Etkinliğe katılmak için giriş yapmalısın.');

    final ref = _firestore.collection(collection).doc(eventId);
    final ticketRef = _firestore
        .collection(EventTicketService.collection)
        .doc(EventTicketService.instance.ticketIdFor(eventId, user.uid));
    final qrToken = EventTicketService.instance.createSecureQrToken();

    final result = await _firestore
        .runTransaction<Map<String, String>>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Etkinlik artık mevcut değil.');

      final data = snapshot.data() ?? const <String, dynamic>{};
      if ((data['status'] ?? 'open') != 'open')
        throw Exception('Bu etkinlik katılıma kapalı.');

      final accessType =
          (data['accessType'] ?? EventAccessType.free.name).toString();
      final paymentStatus =
          (data['paymentStatus'] ?? EventPaymentStatus.notRequired.name)
              .toString();
      if (accessType == EventAccessType.paid.name &&
          paymentStatus != EventPaymentStatus.enabled.name) {
        throw Exception(
            'Bu etkinlik ücretli. Online ödeme ve bilet satışı yakında aktif olacak.');
      }

      final capacity =
          ((data['capacity'] as num?)?.toInt() ?? 1).clamp(1, 2147483647);
      final participants = (data['participantIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();
      final hostId = (data['hostId'] ?? '').toString();
      final title = (data['title'] ?? 'Etkinlik').toString();
      if (hostId.isEmpty)
        throw Exception('Etkinliği düzenleyen kullanıcı bulunamadı.');

      if (!participants.contains(user.uid)) {
        if (participants.length >= capacity)
          throw Exception('Bu etkinlikte boş yer kalmadı.');
        participants.add(user.uid);
        transaction.update(ref, {
          'participantIds': participants,
          'updatedAt': FieldValue.serverTimestamp()
        });
      }

      final existingTicket = await transaction.get(ticketRef);
      if (!existingTicket.exists ||
          (existingTicket.data()?['status'] ?? '').toString() ==
              EventTicketStatus.cancelled.name) {
        final userName = (user.displayName ?? '').trim().isNotEmpty
            ? user.displayName!.trim()
            : 'Katılımcı';
        final isPaid = accessType == EventAccessType.paid.name;
        transaction.set(ticketRef, {
          'id': ticketRef.id,
          'eventId': eventId,
          'eventTitle': title,
          'userId': user.uid,
          'userName': userName,
          'status': isPaid
              ? EventTicketStatus.pendingPayment.name
              : EventTicketStatus.active.name,
          'isPaidEvent': isPaid,
          'priceMinor': ((data['ticketPriceMinor'] as num?)?.toInt() ?? 0),
          'currency': (data['currency'] ?? 'TRY').toString(),
          'qrToken': qrToken,
          'issuedAt': FieldValue.serverTimestamp(),
          'usedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return {'hostId': hostId, 'title': title};
    });

    final hostId = result['hostId'] ?? '';
    final title = result['title'] ?? 'Etkinlik';
    if (hostId != user.uid && hostId.isNotEmpty) {
      try {
        await ChatService.instance.ensureDirectThread(hostId,
            sourceType: 'social_event', sourceId: eventId);
      } catch (_) {}
      final participantName = (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : 'Bir kullanıcı';
      try {
        await AppNotificationService.instance.notifyUser(
          userId: hostId,
          type: 'event_join',
          title: '$participantName etkinliğine katıldı',
          body: title,
          sourceId: eventId,
          actorId: user.uid,
        );
      } catch (_) {}
    }
  }

  Future<void> leave(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection(collection).doc(eventId);
    final ticketRef = _firestore
        .collection(EventTicketService.collection)
        .doc(EventTicketService.instance.ticketIdFor(eventId, user.uid));
    final before = await ref.get();
    final beforeData = before.data() ?? const <String, dynamic>{};
    final hostId = (beforeData['hostId'] ?? '').toString();
    final title = (beforeData['title'] ?? 'Etkinlik').toString();
    final participantIds = (beforeData['participantIds'] as List? ?? const [])
        .map((item) => item.toString())
        .where((id) => id.isNotEmpty && id != user.uid)
        .toList(growable: false);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentHostId = (data['hostId'] ?? '').toString();
      final participants = (data['participantIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();

      if (currentHostId == user.uid) {
        transaction.update(ref,
            {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
        return;
      }

      participants.remove(user.uid);
      transaction.update(ref, {
        'participantIds': participants,
        'updatedAt': FieldValue.serverTimestamp()
      });
      final ticket = await transaction.get(ticketRef);
      if (ticket.exists) {
        transaction.update(ticketRef, {
          'status': EventTicketStatus.cancelled.name,
          'updatedAt': FieldValue.serverTimestamp()
        });
      }
    });

    if (hostId == user.uid && participantIds.isNotEmpty) {
      try {
        await AppNotificationService.instance.notifyUsers(
          userIds: participantIds,
          type: 'event_cancelled',
          title: 'Etkinlik iptal edildi',
          body: title,
          sourceId: eventId,
          actorId: user.uid,
        );
      } catch (_) {}
    }
  }
}
