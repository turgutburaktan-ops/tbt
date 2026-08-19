import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_ticket.dart';
import '../models/photo_spot.dart';
import '../models/social_event.dart';
import 'app_notification_service.dart';
import 'chat_service.dart';
import 'event_ticket_service.dart';
import 'event_trust_service.dart';

class SocialEventService {
  SocialEventService._();
  static final SocialEventService instance = SocialEventService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String collection = 'social_events';

  bool _canView(SocialEvent event) {
    if (event.visibility == EventVisibility.public) return true;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    return event.hostId == uid || event.participantIds.contains(uid) || event.allowedUserIds.contains(uid);
  }

  Stream<List<SocialEvent>> watchUpcoming({String? city, SocialEventType? type, int limit = 80}) {
    return _firestore.collection(collection).limit(limit).snapshots().map((snapshot) {
      final threshold = DateTime.now().subtract(const Duration(minutes: 30));
      final items = snapshot.docs.map(SocialEvent.fromDocument).where((event) {
        if (!_canView(event)) return false;
        if (event.status != 'open' || !event.startsAt.isAfter(threshold)) return false;
        if (city != null && city.trim().isNotEmpty && event.city.toLowerCase() != city.trim().toLowerCase()) return false;
        if (type != null && event.type != type) return false;
        return true;
      }).toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    });
  }

  Stream<List<SocialEvent>> watchForCommunity(String communityId, {int limit = 50}) {
    return _firestore.collection(collection).where('communityId', isEqualTo: communityId).limit(limit).snapshots().map((snapshot) {
      final items = snapshot.docs.map(SocialEvent.fromDocument).where(_canView).toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    });
  }

  Stream<List<SocialEvent>> watchForSpot(String spotId, {int limit = 40}) {
    return _firestore.collection(collection).where('spotId', isEqualTo: spotId).limit(limit).snapshots().map((snapshot) {
      final threshold = DateTime.now().subtract(const Duration(minutes: 30));
      final items = snapshot.docs.map(SocialEvent.fromDocument).where((event) => _canView(event) && event.status == 'open' && event.startsAt.isAfter(threshold)).toList();
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
    EventVisibility visibility = EventVisibility.public,
    List<String> allowedUserIds = const [],
    String? communityId,
    String? communityName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Etkinlik oluşturmak için giriş yapmalısın.');

    final safeTitle = title.trim();
    if (safeTitle.length < 3) throw Exception('Etkinlik başlığı en az 3 karakter olmalı.');
    final minimum = DateTime.now().add(const Duration(minutes: 15));
    if (startsAt.isBefore(minimum)) throw Exception('Etkinlik saati en az 15 dakika ileride olmalı.');
    if (type == SocialEventType.other && customTypeLabel.trim().length < 3) throw Exception('Diğer etkinlik türü için kısa bir ad yazmalısın.');
    if (accessType == EventAccessType.paid && ticketPriceMinor <= 0) throw Exception('Ücretli etkinlik için geçerli bir bilet fiyatı yazmalısın.');
    if (visibility == EventVisibility.selectedPeople && allowedUserIds.where((id) => id.trim().isNotEmpty).isEmpty) {
      throw Exception('Seçili kişiler etkinliği için en az bir kişi seçmelisin.');
    }

    String? safeCommunityId;
    String? safeCommunityName;
    if ((communityId ?? '').trim().isNotEmpty) {
      final communityRef = _firestore.collection('communities').doc(communityId!.trim());
      final community = await communityRef.get();
      if (!community.exists) throw Exception('Topluluk bulunamadı.');
      final data = community.data() ?? const <String, dynamic>{};
      final admins = (data['adminIds'] as List? ?? const []).map((e) => e.toString()).toList();
      if (!admins.contains(user.uid)) throw Exception('Bu topluluk adına etkinlik oluşturma yetkin yok.');
      safeCommunityId = community.id;
      safeCommunityName = (data['name'] ?? communityName ?? '').toString().trim();
    }

    if (accessType == EventAccessType.paid) {
      final eligibility = await EventTrustService.instance.paidEventEligibility();
      if (!eligibility.allowed) throw Exception(eligibility.reason);
    }

    final ref = _firestore.collection(collection).doc();
    final personalName = (user.displayName ?? '').trim().isNotEmpty ? user.displayName!.trim() : 'Topluluk üyesi';
    final hostName = safeCommunityName?.isNotEmpty == true ? safeCommunityName! : personalName;
    final safeAllowedIds = allowedUserIds.map((id) => id.trim()).where((id) => id.isNotEmpty && id != user.uid).toSet().take(300).toList();

    await ref.set({
      'id': ref.id,
      'title': safeTitle,
      'type': type.name,
      'customTypeLabel': customTypeLabel.trim(),
      'hostId': user.uid,
      'hostName': hostName,
      'communityId': safeCommunityId,
      'communityName': safeCommunityName,
      'startsAt': Timestamp.fromDate(startsAt),
      'capacity': capacity < 1 ? 1 : capacity,
      'participantIds': [user.uid],
      'description': description.trim(),
      'city': city.trim().isNotEmpty ? city.trim() : (spot?.city ?? ''),
      'locationLabel': locationLabel.trim().isNotEmpty ? locationLabel.trim() : (spot?.name ?? ''),
      'spotId': spot?.id,
      'spotName': spot?.name,
      'latitude': latitude ?? spot?.latitude,
      'longitude': longitude ?? spot?.longitude,
      'location': latitude != null && longitude != null ? GeoPoint(latitude, longitude) : (spot == null ? null : GeoPoint(spot.latitude, spot.longitude)),
      'status': 'open',
      'approximateLocationOnly': visibility != EventVisibility.public,
      'visibility': visibility.name,
      'allowedUserIds': safeAllowedIds,
      'accessType': accessType.name,
      'ticketPriceMinor': accessType == EventAccessType.paid ? ticketPriceMinor : 0,
      'currency': currency,
      'ticketSalesEndAt': ticketSalesEndAt == null ? null : Timestamp.fromDate(ticketSalesEndAt),
      'paymentStatus': accessType == EventAccessType.paid ? EventPaymentStatus.comingSoon.name : EventPaymentStatus.notRequired.name,
      'paymentProvider': null,
      'externalProductId': null,
      'trustStatus': accessType == EventAccessType.paid ? 'pending_review' : 'new_host',
      'salesStatus': accessType == EventAccessType.paid ? 'blocked' : 'not_required',
      'riskLevel': accessType == EventAccessType.paid ? 'medium' : 'low',
      'reportCount': 0,
      'paymentReleaseStatus': accessType == EventAccessType.paid ? 'held' : 'not_applicable',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> join(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Etkinliğe katılmak için giriş yapmalısın.');
    final ref = _firestore.collection(collection).doc(eventId);
    final ticketRef = _firestore.collection(EventTicketService.collection).doc(EventTicketService.instance.ticketIdFor(eventId, user.uid));
    final qrToken = EventTicketService.instance.createSecureQrToken();

    final result = await _firestore.runTransaction<Map<String, String>>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Etkinlik artık mevcut değil.');
      final data = snapshot.data() ?? const <String, dynamic>{};
      if ((data['status'] ?? 'open') != 'open') throw Exception('Bu etkinlik katılıma kapalı.');
      final visibility = (data['visibility'] ?? 'public').toString();
      final allowed = (data['allowedUserIds'] as List? ?? const []).map((item) => item.toString()).toList();
      final hostId = (data['hostId'] ?? '').toString();
      if (visibility != EventVisibility.public.name && hostId != user.uid && !allowed.contains(user.uid)) throw Exception('Bu etkinlik sadece davet edilen kullanıcılar için.');
      final accessType = (data['accessType'] ?? EventAccessType.free.name).toString();
      final paymentStatus = (data['paymentStatus'] ?? EventPaymentStatus.notRequired.name).toString();
      final trustStatus = (data['trustStatus'] ?? 'new_host').toString();
      final salesStatus = (data['salesStatus'] ?? 'blocked').toString();
      if (accessType == EventAccessType.paid.name && (paymentStatus != EventPaymentStatus.enabled.name || trustStatus != 'approved' || salesStatus != 'open')) {
        throw Exception('Bu ücretli etkinlik güvenlik onayı tamamlanmadan bilet satışına açılamaz.');
      }
      final capacity = ((data['capacity'] as num?)?.toInt() ?? 1).clamp(1, 2147483647);
      final participants = (data['participantIds'] as List? ?? const []).map((item) => item.toString()).toList();
      final title = (data['title'] ?? 'Etkinlik').toString();
      if (hostId.isEmpty) throw Exception('Etkinliği düzenleyen kullanıcı bulunamadı.');
      if (!participants.contains(user.uid)) {
        if (participants.length >= capacity) throw Exception('Bu etkinlikte boş yer kalmadı.');
        participants.add(user.uid);
        transaction.update(ref, {'participantIds': participants, 'updatedAt': FieldValue.serverTimestamp()});
      }
      final existingTicket = await transaction.get(ticketRef);
      if (!existingTicket.exists || (existingTicket.data()?['status'] ?? '').toString() == EventTicketStatus.cancelled.name) {
        final userName = (user.displayName ?? '').trim().isNotEmpty ? user.displayName!.trim() : 'Katılımcı';
        final isPaid = accessType == EventAccessType.paid.name;
        transaction.set(ticketRef, {
          'id': ticketRef.id,
          'eventId': eventId,
          'eventTitle': title,
          'userId': user.uid,
          'userName': userName,
          'status': isPaid ? EventTicketStatus.pendingPayment.name : EventTicketStatus.active.name,
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
      try { await ChatService.instance.ensureDirectThread(hostId, sourceType: 'social_event', sourceId: eventId); } catch (_) {}
      final participantName = (user.displayName ?? '').trim().isNotEmpty ? user.displayName!.trim() : 'Bir kullanıcı';
      try {
        await AppNotificationService.instance.notifyUser(userId: hostId, type: 'event_join', title: '$participantName etkinliğine katıldı', body: title, sourceId: eventId, actorId: user.uid);
      } catch (_) {}
    }
  }

  Future<void> leave(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _firestore.collection(collection).doc(eventId);
    final ticketRef = _firestore.collection(EventTicketService.collection).doc(EventTicketService.instance.ticketIdFor(eventId, user.uid));
    final before = await ref.get();
    final beforeData = before.data() ?? const <String, dynamic>{};
    final hostId = (beforeData['hostId'] ?? '').toString();
    final title = (beforeData['title'] ?? 'Etkinlik').toString();
    final participantIds = (beforeData['participantIds'] as List? ?? const []).map((item) => item.toString()).where((id) => id.isNotEmpty && id != user.uid).toList(growable: false);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentHostId = (data['hostId'] ?? '').toString();
      final participants = (data['participantIds'] as List? ?? const []).map((item) => item.toString()).toList();
      if (currentHostId == user.uid) {
        transaction.update(ref, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
        return;
      }
      participants.remove(user.uid);
      transaction.update(ref, {'participantIds': participants, 'updatedAt': FieldValue.serverTimestamp()});
      final ticket = await transaction.get(ticketRef);
      if (ticket.exists) transaction.update(ticketRef, {'status': EventTicketStatus.cancelled.name, 'updatedAt': FieldValue.serverTimestamp()});
    });

    if (hostId == user.uid && participantIds.isNotEmpty) {
      try {
        await AppNotificationService.instance.notifyUsers(userIds: participantIds, type: 'event_cancelled', title: 'Etkinlik iptal edildi', body: title, sourceId: eventId, actorId: user.uid);
      } catch (_) {}
    }
  }
}
