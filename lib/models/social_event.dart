import 'package:cloud_firestore/cloud_firestore.dart';

enum SocialEventType {
  photography,
  cycling,
  running,
  walking,
  hiking,
  camping,
  followerMeetup,
  trip,
  social,
  concert,
  party,
  theatre,
  seminar,
  workshop,
  festival,
  talk,
  exhibition,
  standUp,
  dance,
  cinema,
  gaming,
  foodDrink,
  networking,
  education,
  charity,
  other,
}

enum EventAccessType { free, paid }

enum EventPaymentStatus { notRequired, comingSoon, enabled }

extension SocialEventTypeX on SocialEventType {
  String get label => switch (this) {
        SocialEventType.photography => 'Fotoğraf',
        SocialEventType.cycling => 'Bisiklet',
        SocialEventType.running => 'Koşu',
        SocialEventType.walking => 'Yürüyüş',
        SocialEventType.hiking => 'Doğa Yürüyüşü',
        SocialEventType.camping => 'Kamp',
        SocialEventType.followerMeetup => 'Takipçi Buluşması',
        SocialEventType.trip => 'Gezi',
        SocialEventType.social => 'Sosyal Buluşma',
        SocialEventType.concert => 'Konser',
        SocialEventType.party => 'Parti',
        SocialEventType.theatre => 'Tiyatro',
        SocialEventType.seminar => 'Seminer',
        SocialEventType.workshop => 'Workshop',
        SocialEventType.festival => 'Festival',
        SocialEventType.talk => 'Söyleşi',
        SocialEventType.exhibition => 'Sergi',
        SocialEventType.standUp => 'Stand-up',
        SocialEventType.dance => 'Dans',
        SocialEventType.cinema => 'Sinema',
        SocialEventType.gaming => 'Oyun / E-spor',
        SocialEventType.foodDrink => 'Yeme İçme',
        SocialEventType.networking => 'Networking',
        SocialEventType.education => 'Eğitim',
        SocialEventType.charity => 'Sosyal Sorumluluk',
        SocialEventType.other => 'Diğer',
      };
}

class SocialEvent {
  final String id;
  final String title;
  final SocialEventType type;
  final String customTypeLabel;
  final String hostId;
  final String hostName;
  final DateTime startsAt;
  final int capacity;
  final List<String> participantIds;
  final String description;
  final String city;
  final String locationLabel;
  final String? spotId;
  final String? spotName;
  final double? latitude;
  final double? longitude;
  final String status;
  final bool approximateLocationOnly;
  final EventAccessType accessType;
  final int ticketPriceMinor;
  final String currency;
  final DateTime? ticketSalesEndAt;
  final EventPaymentStatus paymentStatus;
  final String? paymentProvider;
  final String? externalProductId;

  const SocialEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.customTypeLabel,
    required this.hostId,
    required this.hostName,
    required this.startsAt,
    required this.capacity,
    required this.participantIds,
    required this.description,
    required this.city,
    required this.locationLabel,
    required this.spotId,
    required this.spotName,
    required this.status,
    required this.approximateLocationOnly,
    this.latitude,
    this.longitude,
    this.accessType = EventAccessType.free,
    this.ticketPriceMinor = 0,
    this.currency = 'TRY',
    this.ticketSalesEndAt,
    this.paymentStatus = EventPaymentStatus.notRequired,
    this.paymentProvider,
    this.externalProductId,
  });

  int get participantCount => participantIds.length;
  int get remainingSlots => capacity - participantCount;
  bool get isFull => participantCount >= capacity;
  bool get isOpen => status == 'open' && !isFull;
  bool get isPaid => accessType == EventAccessType.paid;
  bool get paymentAvailable =>
      isPaid && paymentStatus == EventPaymentStatus.enabled;
  bool get hasCoordinates => latitude != null && longitude != null;
  double get ticketPrice => ticketPriceMinor / 100.0;
  String get typeLabel =>
      type == SocialEventType.other && customTypeLabel.trim().isNotEmpty
          ? customTypeLabel.trim()
          : type.label;

  factory SocialEvent.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawStartsAt = data['startsAt'];
    final startsAt = rawStartsAt is Timestamp
        ? rawStartsAt.toDate()
        : DateTime.tryParse(rawStartsAt?.toString() ?? '') ?? DateTime.now();
    final rawSalesEnd = data['ticketSalesEndAt'];
    final salesEnd = rawSalesEnd is Timestamp
        ? rawSalesEnd.toDate()
        : DateTime.tryParse(rawSalesEnd?.toString() ?? '');
    final rawType = (data['type'] ?? 'social').toString();
    final type = SocialEventType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => SocialEventType.social,
    );
    final rawParticipants = data['participantIds'];
    final participantIds = rawParticipants is List
        ? rawParticipants
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList()
        : <String>[];
    final rawAccess = (data['accessType'] ?? 'free').toString();
    final access = EventAccessType.values.firstWhere(
      (value) => value.name == rawAccess,
      orElse: () => EventAccessType.free,
    );
    final rawPayment = (data['paymentStatus'] ??
            (access == EventAccessType.paid ? 'comingSoon' : 'notRequired'))
        .toString();
    final payment = EventPaymentStatus.values.firstWhere(
      (value) => value.name == rawPayment,
      orElse: () => access == EventAccessType.paid
          ? EventPaymentStatus.comingSoon
          : EventPaymentStatus.notRequired,
    );
    final geo = data['location'];
    final lat = (data['latitude'] as num?)?.toDouble() ??
        (geo is GeoPoint ? geo.latitude : null);
    final lng = (data['longitude'] as num?)?.toDouble() ??
        (geo is GeoPoint ? geo.longitude : null);

    return SocialEvent(
      id: doc.id,
      title: (data['title'] ?? 'Sosyal etkinlik').toString(),
      type: type,
      customTypeLabel: (data['customTypeLabel'] ?? '').toString(),
      hostId: (data['hostId'] ?? '').toString(),
      hostName: (data['hostName'] ?? 'Topluluk üyesi').toString(),
      startsAt: startsAt,
      capacity: ((data['capacity'] as num?)?.toInt() ?? 1).clamp(1, 2147483647),
      participantIds: participantIds,
      description: (data['description'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      locationLabel: (data['locationLabel'] ?? '').toString(),
      spotId: data['spotId']?.toString(),
      spotName: data['spotName']?.toString(),
      latitude: lat,
      longitude: lng,
      status: (data['status'] ?? 'open').toString(),
      approximateLocationOnly: data['approximateLocationOnly'] != false,
      accessType: access,
      ticketPriceMinor: ((data['ticketPriceMinor'] as num?)?.toInt() ?? 0)
          .clamp(0, 1000000000),
      currency: (data['currency'] ?? 'TRY').toString(),
      ticketSalesEndAt: salesEnd,
      paymentStatus: payment,
      paymentProvider: data['paymentProvider']?.toString(),
      externalProductId: data['externalProductId']?.toString(),
    );
  }
}
