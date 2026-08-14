import 'package:cloud_firestore/cloud_firestore.dart';

enum EventTicketStatus { pendingPayment, active, used, cancelled, refunded }

class EventTicket {
  final String id;
  final String eventId;
  final String eventTitle;
  final String userId;
  final String userName;
  final EventTicketStatus status;
  final bool isPaidEvent;
  final int priceMinor;
  final String currency;
  final String qrToken;
  final DateTime? issuedAt;
  final DateTime? usedAt;

  const EventTicket({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.userId,
    required this.userName,
    required this.status,
    required this.isPaidEvent,
    required this.priceMinor,
    required this.currency,
    required this.qrToken,
    required this.issuedAt,
    required this.usedAt,
  });

  bool get isActive => status == EventTicketStatus.active;
  bool get canEnter => status == EventTicketStatus.active;

  factory EventTicket.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawStatus = (data['status'] ?? 'active').toString();
    final status = EventTicketStatus.values.firstWhere(
      (value) => value.name == rawStatus,
      orElse: () => EventTicketStatus.active,
    );

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return DateTime.tryParse(value?.toString() ?? '');
    }

    return EventTicket(
      id: doc.id,
      eventId: (data['eventId'] ?? '').toString(),
      eventTitle: (data['eventTitle'] ?? 'Etkinlik').toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'Katılımcı').toString(),
      status: status,
      isPaidEvent: data['isPaidEvent'] == true,
      priceMinor: ((data['priceMinor'] as num?)?.toInt() ?? 0).clamp(0, 1000000000),
      currency: (data['currency'] ?? 'TRY').toString(),
      qrToken: (data['qrToken'] ?? '').toString(),
      issuedAt: readDate(data['issuedAt']),
      usedAt: readDate(data['usedAt']),
    );
  }
}
