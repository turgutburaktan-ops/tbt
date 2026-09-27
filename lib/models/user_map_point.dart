import 'package:cloud_firestore/cloud_firestore.dart';

class UserMapPoint {
  final String id;
  final String ownerId;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final bool communitySuggested;
  final String moderationStatus;
  final DateTime createdAt;

  const UserMapPoint({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.communitySuggested,
    required this.moderationStatus,
    required this.createdAt,
  });

  factory UserMapPoint.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserMapPoint(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? 'İsimsiz Nokta',
      category: data['category'] as String? ?? 'Diğer',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      communitySuggested: data['communitySuggested'] == true,
      moderationStatus: data['moderationStatus'] as String? ?? 'private',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
