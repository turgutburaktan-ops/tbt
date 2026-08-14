import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_spot.dart';
import '../models/social_event.dart';
import 'app_notification_service.dart';
import 'chat_service.dart';

class SocialEventService {
  SocialEventService._();

  static final SocialEventService instance = SocialEventService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String collection = 'social_events';

  Stream<List<SocialEvent>> watchUpcoming({
    String? city,
    SocialEventType? type,
    int limit = 80,
  }) {
    return _firestore
        .collection(collection)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final threshold = DateTime.now().subtract(const Duration(minutes: 30));
          final items = snapshot.docs
              .map(SocialEvent.fromDocument)
              .where((event) {
                if (event.status != 'open' || !event.startsAt.isAfter(threshold)) {
                  return false;
                }
                if (city != null &&
                    city.trim().isNotEmpty &&
                    event.city.toLowerCase() != city.trim().toLowerCase()) {
                  return false;
                }
                if (type != null && event.type != type) return false;
                return true;
              })
              .toList();
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
              .where(
                (event) =>
                    event.status == 'open' && event.startsAt.isAfter(threshold),
              )
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
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Etkinlik oluşturmak için giriş yapmalısın.');
    }

    final safeTitle = title.trim();
    if (safeTitle.length < 3) {
      throw Exception('Etkinlik başlığı en az 3 karakter olmalı.');
    }

    final minimum = DateTime.now().add(const Duration(minutes: 15));
    if (startsAt.isBefore(minimum)) {
      throw Exception('Etkinlik saati en az 15 dakika ileride olmalı.');
    }

    if (type == SocialEventType.other && customTypeLabel.trim().length < 3) {
      throw Exception('Diğer etkinlik türü için kısa bir ad yazmalısın.');
    }

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
      'capacity': capacity.clamp(2, 100),
      'participantIds': [user.uid],
      'description': description.trim(),
      'city': city.trim().isNotEmpty ? city.trim() : (spot?.city ?? ''),
      'locationLabel': locationLabel.trim().isNotEmpty
          ? locationLabel.trim()
          : (spot?.name ?? ''),
      'spotId': spot?.id,
      'spotName': spot?.name,
      'status': 'open',
      'approximateLocationOnly': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> join(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Etkinliğe katılmak için giriş yapmalısın.');
    }

    final ref = _firestore.collection(collection).doc(eventId);
    final result = await _firestore.runTransaction<Map<String, String>>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Etkinlik artık mevcut değil.');

      final data = snapshot.data() ?? const <String, dynamic>{};
      if ((data['status'] ?? 'open') != 'open') {
        throw Exception('Bu etkinlik katılıma kapalı.');
      }

      final capacity = ((data['capacity'] as num?)?.toInt() ?? 2).clamp(2, 100);
      final participants = (data['participantIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();
      final hostId = (data['hostId'] ?? '').toString();
      final title = (data['title'] ?? 'Etkinlik').toString();

      if (hostId.isEmpty) {
        throw Exception('Etkinliği düzenleyen kullanıcı bulunamadı.');
      }

      if (!participants.contains(user.uid)) {
        if (participants.length >= capacity) {
          throw Exception('Bu etkinlikte boş yer kalmadı.');
        }
        participants.add(user.uid);
        transaction.update(ref, {
          'participantIds': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return {'hostId': hostId, 'title': title};
    });

    final hostId = result['hostId'] ?? '';
    final title = result['title'] ?? 'Etkinlik';
    if (hostId == user.uid || hostId.isEmpty) return;

    try {
      await ChatService.instance.ensureDirectThread(
        hostId,
        sourceType: 'social_event',
        sourceId: eventId,
      );
    } catch (_) {
      // Katılım tamamlandıysa geçici sohbet hatası etkinlik katılımını bozmaz.
    }

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
    } catch (_) {
      // Bildirim hatası etkinlik katılımını bozmaz.
    }
  }

  Future<void> leave(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection(collection).doc(eventId);
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
        transaction.update(ref, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      participants.remove(user.uid);
      transaction.update(ref, {
        'participantIds': participants,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
      } catch (_) {
        // İptal tamamlandıysa bildirim hatası işlemi geri döndürmez.
      }
    }
  }
}
