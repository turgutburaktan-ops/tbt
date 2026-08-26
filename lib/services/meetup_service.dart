import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_spot.dart';
import '../models/spot_meetup.dart';
import 'chat_service.dart';

class MeetupService {
  MeetupService._();

  static final MeetupService instance = MeetupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String collection = 'spot_meetups';

  Stream<List<SpotMeetup>> watchUpcomingForSpot(
    String spotId, {
    int limit = 40,
  }) {
    return _firestore
        .collection(collection)
        .where('spotId', isEqualTo: spotId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final threshold = DateTime.now().subtract(
            const Duration(minutes: 30),
          );
          final items = snapshot.docs
              .map(SpotMeetup.fromDocument)
              .where(
                (item) =>
                    item.status == 'open' && item.startsAt.isAfter(threshold),
              )
              .toList();
          items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
          return items;
        });
  }

  Future<String> createMeetup({
    required PhotoSpot spot,
    required DateTime startsAt,
    required int capacity,
    String purpose = 'Fotoğraf çekimi',
    String note = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
        'Birlikte Git buluşması oluşturmak için giriş yapmalısın.',
      );
    }

    final minimum = DateTime.now().add(const Duration(minutes: 15));
    if (startsAt.isBefore(minimum)) {
      throw Exception('Buluşma saati en az 15 dakika ileride olmalı.');
    }

    final safeCapacity = capacity.clamp(2, 12);
    final ref = _firestore.collection(collection).doc();
    final hostName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : 'Fotoğraf tutkunu';

    await ref.set({
      'id': ref.id,
      'spotId': spot.id,
      'spotName': spot.name,
      'city': spot.city,
      'hostId': user.uid,
      'hostName': hostName,
      'startsAt': Timestamp.fromDate(startsAt),
      'capacity': safeCapacity,
      'participantIds': [user.uid],
      'purpose': purpose.trim().isEmpty ? 'Fotoğraf çekimi' : purpose.trim(),
      'note': note.trim(),
      'status': 'open',
      'approximateLocationOnly': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<bool> join(String meetupId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Buluşmaya katılmak için giriş yapmalısın.');
    }

    final ref = _firestore.collection(collection).doc(meetupId);

    final hostId = await _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('Buluşma artık mevcut değil.');

      final data = snapshot.data() ?? const <String, dynamic>{};
      if ((data['status'] ?? 'open') != 'open') {
        throw Exception('Bu buluşma katılıma kapalı.');
      }

      final capacity = ((data['capacity'] as num?)?.toInt() ?? 2).clamp(2, 12);
      final participants = (data['participantIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();
      final hostId = (data['hostId'] ?? '').toString();

      if (hostId.isEmpty) {
        throw Exception('Buluşmanın sahibi bulunamadı.');
      }

      if (!participants.contains(user.uid)) {
        if (participants.length >= capacity) {
          throw Exception('Bu buluşmada boş yer kalmadı.');
        }
        participants.add(user.uid);
        transaction.update(ref, {
          'participantIds': participants,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return hostId;
    });

    if (hostId == user.uid) return true;

    try {
      await ChatService.instance.ensureDirectThread(
        hostId,
        sourceType: 'meetup',
        sourceId: meetupId,
      );
      return true;
    } catch (_) {
      // Katılım Firestore'da başarılıdır. Chat kurulumu ayrı bir yan etkidir;
      // geçici mesajlaşma hatası katılımı başarısız gibi göstermemelidir.
      return false;
    }
  }

  Future<void> leave(String meetupId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection(collection).doc(meetupId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? const <String, dynamic>{};
      final hostId = (data['hostId'] ?? '').toString();
      final participants = (data['participantIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList();

      if (hostId == user.uid) {
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
  }
}
