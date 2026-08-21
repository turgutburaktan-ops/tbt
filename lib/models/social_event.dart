import 'package:cloud_firestore/cloud_firestore.dart';

enum SocialEventType { photography, cycling, running, walking, hiking, camping, followerMeetup, trip, social, concert, party, theatre, seminar, workshop, festival, talk, exhibition, standUp, dance, cinema, gaming, foodDrink, networking, education, charity, other }
enum EventAccessType { free, paid }
enum EventPaymentStatus { notRequired, comingSoon, enabled }
enum EventVisibility { public, followers, mutuals, closeFriends, selectedPeople, private }
enum EventAttendanceChoice { attending, interested, hidden }

extension EventAttendanceChoiceX on EventAttendanceChoice {
  String get label => switch (this) {
        EventAttendanceChoice.attending => 'Katılıyorum',
        EventAttendanceChoice.interested => 'İlgileniyorum',
        EventAttendanceChoice.hidden => 'Gizli katıl',
      };
}

extension EventVisibilityX on EventVisibility {
  String get label => switch (this) {
        EventVisibility.public => 'Herkese Açık',
        EventVisibility.followers => 'Takipçiler',
        EventVisibility.mutuals => 'Karşılıklı Takip',
        EventVisibility.closeFriends => 'Yakın Arkadaşlar',
        EventVisibility.selectedPeople => 'Seçili Kişiler',
        EventVisibility.private => 'Sadece Ben',
      };
}

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
  final String id, title, customTypeLabel, hostId, hostName, description, city,
      locationLabel, status, currency, trustStatus, salesStatus, riskLevel,
      paymentReleaseStatus;
  final SocialEventType type;
  final DateTime startsAt;
  final int capacity, ticketPriceMinor, reportCount, interestedCount,
      privateParticipantCount;
  final List<String> participantIds, allowedUserIds;
  final String? spotId, spotName, communityId, communityName, paymentProvider,
      externalProductId;
  final double? latitude, longitude;
  final bool approximateLocationOnly;
  final EventAccessType accessType;
  final DateTime? ticketSalesEndAt;
  final EventPaymentStatus paymentStatus;
  final EventVisibility visibility;

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
    this.communityId,
    this.communityName,
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
    this.trustStatus = 'new_host',
    this.salesStatus = 'blocked',
    this.riskLevel = 'low',
    this.reportCount = 0,
    this.paymentReleaseStatus = 'not_applicable',
    this.visibility = EventVisibility.public,
    this.allowedUserIds = const [],
    this.interestedCount = 0,
    this.privateParticipantCount = 0,
  });

  int get visibleParticipantCount => participantIds.length;
  int get participantCount => participantIds.length + privateParticipantCount;
  int get remainingSlots => capacity - participantCount;
  bool get isFull => participantCount >= capacity;
  bool get isOpen => status == 'open' && !isFull;
  bool get isPaid => accessType == EventAccessType.paid;
  bool get paymentAvailable => isPaid && paymentStatus == EventPaymentStatus.enabled;
  bool get hasCoordinates => latitude != null && longitude != null;
  double get ticketPrice => ticketPriceMinor / 100.0;
  String get typeLabel => type == SocialEventType.other && customTypeLabel.trim().isNotEmpty
      ? customTypeLabel.trim()
      : type.label;

  bool isAttending(String uid) => participantIds.contains(uid);
  bool isInterested(String uid) => false;
  bool isHidden(String uid) => false;

  factory SocialEvent.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    DateTime date(dynamic v) => v is Timestamp
        ? v.toDate()
        : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    List<String> list(dynamic v) => v is List
        ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final type = SocialEventType.values.firstWhere(
      (e) => e.name == (d['type'] ?? 'social'),
      orElse: () => SocialEventType.social,
    );
    final access = EventAccessType.values.firstWhere(
      (e) => e.name == (d['accessType'] ?? 'free'),
      orElse: () => EventAccessType.free,
    );
    final payment = EventPaymentStatus.values.firstWhere(
      (e) => e.name ==
          (d['paymentStatus'] ??
              (access == EventAccessType.paid ? 'comingSoon' : 'notRequired')),
      orElse: () => EventPaymentStatus.notRequired,
    );
    final visibility = EventVisibility.values.firstWhere(
      (e) => e.name == (d['visibility'] ?? 'public'),
      orElse: () => EventVisibility.public,
    );
    final geo = d['location'];
    return SocialEvent(
      id: doc.id,
      title: (d['title'] ?? 'Sosyal etkinlik').toString(),
      type: type,
      customTypeLabel: (d['customTypeLabel'] ?? '').toString(),
      hostId: (d['hostId'] ?? '').toString(),
      hostName: (d['hostName'] ?? 'Topluluk üyesi').toString(),
      startsAt: date(d['startsAt']),
      capacity: ((d['capacity'] as num?)?.toInt() ?? 1).clamp(1, 2147483647),
      participantIds: list(d['participantIds']),
      description: (d['description'] ?? '').toString(),
      city: (d['city'] ?? '').toString(),
      locationLabel: (d['locationLabel'] ?? '').toString(),
      spotId: d['spotId']?.toString(),
      spotName: d['spotName']?.toString(),
      communityId: d['communityId']?.toString(),
      communityName: d['communityName']?.toString(),
      latitude: (d['latitude'] as num?)?.toDouble() ??
          (geo is GeoPoint ? geo.latitude : null),
      longitude: (d['longitude'] as num?)?.toDouble() ??
          (geo is GeoPoint ? geo.longitude : null),
      status: (d['status'] ?? 'open').toString(),
      approximateLocationOnly: d['approximateLocationOnly'] != false,
      accessType: access,
      ticketPriceMinor:
          ((d['ticketPriceMinor'] as num?)?.toInt() ?? 0).clamp(0, 1000000000),
      currency: (d['currency'] ?? 'TRY').toString(),
      ticketSalesEndAt:
          d['ticketSalesEndAt'] == null ? null : date(d['ticketSalesEndAt']),
      paymentStatus: payment,
      paymentProvider: d['paymentProvider']?.toString(),
      externalProductId: d['externalProductId']?.toString(),
      trustStatus: (d['trustStatus'] ?? 'new_host').toString(),
      salesStatus: (d['salesStatus'] ?? 'blocked').toString(),
      riskLevel: (d['riskLevel'] ?? 'low').toString(),
      reportCount:
          ((d['reportCount'] as num?)?.toInt() ?? 0).clamp(0, 2147483647),
      paymentReleaseStatus: (d['paymentReleaseStatus'] ??
              (access == EventAccessType.paid ? 'held' : 'not_applicable'))
          .toString(),
      visibility: visibility,
      allowedUserIds: list(d['allowedUserIds']),
      interestedCount:
          ((d['interestedCount'] as num?)?.toInt() ?? 0).clamp(0, 2147483647),
      privateParticipantCount:
          ((d['privateParticipantCount'] as num?)?.toInt() ?? 0).clamp(0, 2147483647),
    );
  }
}
