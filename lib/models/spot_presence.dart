import 'package:cloud_firestore/cloud_firestore.dart';

class SpotPresence {
  final String id;
  final String spotId;
  final String userId;
  final String displayName;
  final String photoUrl;
  final String roleLabel;
  final bool visible;
  final bool approximateLocationOnly;
  final DateTime? checkedInAt;
  final DateTime? expiresAt;

  const SpotPresence({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.roleLabel,
    required this.visible,
    required this.approximateLocationOnly,
    required this.checkedInAt,
    required this.expiresAt,
  });

  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  factory SpotPresence.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return SpotPresence(
      id: document.id,
      spotId: (data['spotId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      displayName: (data['displayName'] ?? 'Fotoğraf tutkunu').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      roleLabel: (data['roleLabel'] ?? '').toString(),
      visible: data['visible'] == true,
      approximateLocationOnly: data['approximateLocationOnly'] != false,
      checkedInAt: readDate(data['checkedInAt']),
      expiresAt: readDate(data['expiresAt']),
    );
  }
}
