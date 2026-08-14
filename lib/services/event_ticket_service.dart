import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_ticket.dart';

class EventTicketService {
  EventTicketService._();
  static final EventTicketService instance = EventTicketService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String collection = 'event_tickets';

  String ticketIdFor(String eventId, String userId) => '${eventId}_$userId';

  String createSecureQrToken() {
    final random = Random.secure();
    final values = List<int>.generate(24, (_) => random.nextInt(256));
    return values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  Stream<List<EventTicket>> watchMyTickets({int limit = 100}) {
    final user = _auth.currentUser;
    if (user == null) return const Stream<List<EventTicket>>.empty();
    return _firestore
        .collection(collection)
        .where('userId', isEqualTo: user.uid)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map(EventTicket.fromDocument).toList();
          items.sort((a, b) {
            final at = a.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bt.compareTo(at);
          });
          return items;
        });
  }

  Stream<EventTicket?> watchTicket(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream<EventTicket?>.empty();
    final id = ticketIdFor(eventId, user.uid);
    return _firestore.collection(collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return EventTicket.fromDocument(doc);
    });
  }

  Future<void> markUsed({required String qrToken, required String eventId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Bilet kontrolü için giriş yapmalısın.');

    final query = await _firestore
        .collection(collection)
        .where('eventId', isEqualTo: eventId)
        .where('qrToken', isEqualTo: qrToken)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Bilet bulunamadı.');
    final ticketRef = query.docs.first.reference;
    final eventRef = _firestore.collection('social_events').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final event = await transaction.get(eventRef);
      if (!event.exists) throw Exception('Etkinlik bulunamadı.');
      final eventData = event.data() ?? const <String, dynamic>{};
      if ((eventData['hostId'] ?? '').toString() != user.uid) {
        throw Exception('Bu etkinliğin biletlerini yalnızca organizatör kontrol edebilir.');
      }

      final ticket = await transaction.get(ticketRef);
      final ticketData = ticket.data() ?? const <String, dynamic>{};
      if ((ticketData['status'] ?? '').toString() != EventTicketStatus.active.name) {
        throw Exception('Bu bilet aktif değil veya daha önce kullanılmış.');
      }
      transaction.update(ticketRef, {
        'status': EventTicketStatus.used.name,
        'usedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
