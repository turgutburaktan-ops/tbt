import 'package:cloud_firestore/cloud_firestore.dart';

class SpotMeetup {
  final String id;
  final String spotId;
  final String spotName;
  final String city;
  final String hostId;
  final String hostName;
  final DateTime startsAt;
  final int capacity;
  final List<String> participantIds;
  final String purpose;
  final String note;
  final String status;
  final bool approximateLocationOnly;

  const SpotMeetup({
    required this.id,
    required this.spotId,
    required this.spotName,
    required this.city,
    required this.hostId,
    required this.hostName,
    required this.startsAt,
    required this.capacity,
    required this.participantIds,
    required this.purpose,
    required this.note,
    required this.status,
    required this.approximateLocationOnly,
  });

  int get participantCount => participantIds.length;
  int get remainingSlots => capacity - participantCount;
  bool get isFull => participantCount >= capacity;
  bool get isOpen => status == 'open' && !isFull;

  factory SpotMeetup.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawStartsAt = data['startsAt'];
    final startsAt = rawStartsAt is Timestamp
        ? rawStartsAt.toDate()
        : DateTime.tryParse(rawStartsAt?.toString() ?? '') ?? DateTime.now();

    List<String> ids(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return SpotMeetup(
      id: doc.id,
      spotId: (data['spotId'] ?? '').toString(),
      spotName: (data['spotName'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      hostId: (data['hostId'] ?? '').toString(),
      hostName: (data['hostName'] ?? 'Fotoğraf tutkunu').toString(),
      startsAt: startsAt,
      capacity: ((data['capacity'] as num?)?.toInt() ?? 2).clamp(2, 12),
      participantIds: ids(data['participantIds']),
      purpose: (data['purpose'] ?? 'Fotoğraf çekimi').toString(),
      note: (data['note'] ?? '').toString(),
      status: (data['status'] ?? 'open').toString(),
      approximateLocationOnly: data['approximateLocationOnly'] != false,
    );
  }
}
